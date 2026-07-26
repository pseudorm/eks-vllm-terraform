"""
Locust load testing script that simulates Claude Code heavy user patterns for LiteLLM endpoint.

This simulates power users (heavy usage pattern) with:
- Streaming requests (primary interaction mode)
- Long conversation sessions (10-30 turns)
- High frequency interactions (1-3s wait between messages)
- Large context windows with code files and tool outputs
- Multi-turn conversations with accumulated history

Usage:
    # Simulate 200 heavy Claude Code users
    locust -f locustfile_claude_code.py --host https://chester.ai --users 200 --spawn-rate 10 --headless

    # With Web UI to monitor
    locust -f locustfile_claude_code.py --host https://chester.ai

Install dependencies:
    pip install locust
"""

import json
import os
import random
import time
from datetime import datetime

from locust import HttpUser, between, events, task

# Available models for load testing - shown as dropdown in Locust UI
AVAILABLE_MODELS = [
    "load-test/model",
    "bedrock/us.amazon.nova-micro-v1:0",
    "bedrock/us.amazon.nova-lite-v1:0",
    "bedrock/us.amazon.nova-pro-v1:0",
    "bedrock/us.anthropic.claude-3-5-haiku-20241022-v1:0",
    "bedrock/us.anthropic.claude-sonnet-4-20250514-v1:0",
    "claude-opus-4-7",
]


@events.init_command_line_parser.add_listener
def _(parser):
    """Add custom CLI args - these also appear as fields in the Locust web UI."""
    parser.add_argument(
        "--model",
        type=str,
        default="load-test/model",
        choices=AVAILABLE_MODELS,
        help="Model to load test against",
        include_in_web_ui=True,
    )


class ClaudeCodeUser(HttpUser):
    """
    Simulates a real Claude Code user interacting with LiteLLM.

    Realistic behavior:
    - Each user has a session with multiple conversation turns
    - Primarily uses streaming responses (like Claude Code does)
    - Builds up conversation history over time
    - Has realistic "think time" between messages (reading response, typing next prompt)
    - Mix of simple queries and complex tasks (code review, debugging, refactoring)
    """

    # Heavy user wait time: 1-3 seconds between messages
    # (Simulates power users who interact frequently)
    wait_time = between(1, 3)

    def on_start(self):
        """Initialize a new Claude Code session"""
        self.api_key = os.getenv("LITELLM_API_KEY", "sk-1234")
        self.headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
            # Disable HTTP keep-alive so each request opens a new TCP connection.
            # kube-proxy load balances per-connection, so reusing connections pins
            # traffic to a subset of pods and skews KEDA scaling tests.
            "Connection": "close",
        }
        # Disable urllib3 connection pooling on the Locust HTTP client
        adapter = self.client.get_adapter("https://")
        adapter.poolmanager.connection_pool_kw["maxsize"] = 1
        self.client.headers.update({"Connection": "close"})

        # Each user has their own conversation history
        self.conversation_history = []

        # Track how many turns this user has had
        self.turn_count = 0

        # Heavy user session length (10-30 turns)
        self.max_turns = random.randint(10, 30)

        # Read model from Locust CLI arg / Web UI selection
        self.model = self.environment.parsed_options.model
        self.models = [self.model]

    def _get_realistic_prompt(self):
        """
        Generate realistic prompts that Claude Code users would send.
        Includes large context like file contents, tool results, etc.
        Simulates the actual ~60k token contexts Claude Code sends.
        """

        # Simulate large file contents that Claude Code includes
        large_code_file = (
            """
        def process_data(data):
            '''Process incoming data from API'''
            results = []
            for item in data:
                if item.get('status') == 'active':
                    processed = transform_item(item)
                    results.append(processed)
            return results

        def transform_item(item):
            '''Transform individual item'''
            return {
                'id': item['id'],
                'name': item['name'],
                'value': item.get('value', 0) * 1.5,
                'timestamp': item['timestamp']
            }
        """
            * 50
        )  # Repeat to simulate large file

        # Simulate tool results/outputs that Claude Code includes
        tool_output = (
            """
        File: src/main.py (234 lines)
        File: src/utils.py (156 lines)
        File: tests/test_main.py (89 lines)

        Git status: 15 modified files
        Recent commits: 8 commits in last 24 hours

        Dependencies: 47 packages installed
        Python version: 3.11.5
        """
            * 20
        )  # Repeat to add bulk

        if self.turn_count == 0:
            # First message - includes lots of context
            first_prompts = [
                f"Help me debug this error in my Python script.\n\n```python\n{large_code_file}\n```\n\nError: {tool_output}",
                f"Can you review this pull request?\n\nFiles changed:\n{tool_output}\n\nCode:\n```python\n{large_code_file}\n```",
                f"I need to refactor this component:\n\n```python\n{large_code_file}\n```\n\nCurrent structure:\n{tool_output}",
                f"Explain how this authentication flow works:\n\n```python\n{large_code_file}\n```\n\nContext:\n{tool_output}",
                f"Write a test for this function:\n\n```python\n{large_code_file}\n```\n\nExisting tests:\n{tool_output}",
            ]
            return random.choice(first_prompts)
        else:
            # Follow-up messages - still include context
            followup_prompts = [
                f"Can you show me how to implement that?\n\nCurrent code:\n```python\n{large_code_file[:500]}\n```",
                f"What about edge cases?\n\nHere's the implementation:\n```python\n{large_code_file[:500]}\n```",
                f"Can you add error handling?\n\nCurrent code:\n```python\n{large_code_file[:500]}\n```",
                "Make it more concise",
                "Can you explain that part in more detail?",
                "How would I test this?",
                "What are the performance implications?",
                "Is there a more efficient way?",
            ]
            return random.choice(followup_prompts)

    def _add_to_conversation(self, role, content):
        """Add a message to conversation history"""
        self.conversation_history.append({"role": role, "content": content})

        # Claude Code keeps much longer history (doesn't truncate aggressively)
        # Keep last 30 messages to simulate real context size
        if len(self.conversation_history) > 30:
            self.conversation_history = self.conversation_history[-30:]

    @task
    def claude_code_interaction(self):
        """
        Simulates a single Claude Code user interaction.
        This is the main task that represents a user sending a message.
        """

        # If user has completed their session, start a new one
        if self.turn_count >= self.max_turns:
            self.conversation_history = []
            self.turn_count = 0
            self.max_turns = random.randint(3, 15)
            self.model = random.choice(self.models)

        # Generate user prompt
        user_prompt = self._get_realistic_prompt()
        self._add_to_conversation("user", user_prompt)

        # Build the request payload with full conversation history
        # This is how Claude Code sends requests - includes all context (~60k tokens)
        payload = {
            "model": self.model,
            "messages": self.conversation_history.copy(),
            "max_tokens": random.randint(
                100, 500
            ),  # Reduced for cost-effective load testing
            "temperature": 0.7,
            "stream": True,  # Claude Code almost always uses streaming,
            "stream_options": {"include_usage": True},
        }

        # Estimate input token count (rough approximation)
        # Claude Code typically sends 50k-70k input tokens per request
        total_chars = sum(
            len(str(msg.get("content", ""))) for msg in payload["messages"]
        )
        estimated_input_tokens = total_chars // 4  # Rough estimate: 4 chars per token

        request_start = time.time()
        chunk_count = 0

        # Send streaming request (this is the primary Claude Code interaction pattern)
        with self.client.post(
            "/v1/chat/completions",
            json=payload,
            headers=self.headers,
            stream=True,
            catch_response=True,
            name=f"Claude Code Chat (turn {self.turn_count + 1})",
        ) as response:
            if response.status_code == 200:
                try:
                    # Consume the stream
                    last_chunk = None

                    for line in response.iter_lines():
                        if line:
                            line_str = line.decode("utf-8")
                            if line_str.startswith("data: "):
                                data_str = line_str[6:]
                                if data_str.strip() != "[DONE]":
                                    try:
                                        chunk_data = json.loads(data_str)
                                        last_chunk = chunk_data
                                        chunk_count += 1
                                    except json.JSONDecodeError:
                                        pass

                    request_duration = (
                        time.time() - request_start
                    )  # Total time (seconds)

                    # Get actual token usage from the last chunk
                    if last_chunk and "usage" in last_chunk:
                        usage = last_chunk["usage"]
                        prompt_tokens = usage.get("prompt_tokens", 0)
                        completion_tokens = usage.get("completion_tokens", 0)

                        # Extract assistant response for conversation history
                        assistant_response = "Response received"
                        if "choices" in last_chunk and len(last_chunk["choices"]) > 0:
                            message = last_chunk["choices"][0].get("message", {})
                            assistant_response = message.get(
                                "content", "Response received"
                            )

                        self._add_to_conversation("assistant", assistant_response)
                        self.turn_count += 1
                        response.success()

                        # Log actual token usage and total time
                        total_time_ms = request_duration * 1000
                        print(
                            f"[User {id(self) % 10000:04d}] Turn {self.turn_count}: "
                            f"{prompt_tokens:,} in + {completion_tokens:,} out tokens, "
                            f"Total: {request_duration:.2f}s ({total_time_ms:.0f}ms), "
                            f"Chunks: {chunk_count}"
                        )
                    else:
                        response.failure("No usage data in response")

                except Exception as e:
                    response.failure(f"Streaming error: {str(e)}")
            else:
                response.failure(f"HTTP {response.status_code}")




# Event handlers for monitoring
@events.test_start.add_listener
def on_test_start(environment, **kwargs):
    print(f"\n{'=' * 70}")
    print(f"Starting Claude Code Usage Simulation")
    print(f"Target: {environment.host}/litellm")
    print(f"Simulating heavy power users (high frequency interactions)")
    print(f"User profile:")
    print(f"  - Session length: 10-30 turns per user")
    print(f"  - Wait time: 1-3 seconds between messages")
    print(f"  - Interaction pattern: Frequent, sustained coding sessions")
    print(f"{'=' * 70}\n")


@events.test_stop.add_listener
def on_test_stop(environment, **kwargs):
    print(f"\n{'=' * 70}")
    print(f"Claude Code simulation completed")

    stats = environment.stats
    print(f"\nSummary:")
    print(f"  Total requests: {stats.total.num_requests}")
    print(f"  Failed requests: {stats.total.num_failures}")
    print(f"  Failure rate: {stats.total.fail_ratio * 100:.2f}%")
    print(
        f"  Median response time: {stats.total.get_response_time_percentile(0.5):.0f}ms"
    )
    print(f"  95th percentile: {stats.total.get_response_time_percentile(0.95):.0f}ms")
    print(f"  RPS: {stats.total.total_rps:.2f}")
    print(f"{'=' * 70}\n")


# Custom metrics tracking
request_count = 0
total_chunks = 0


@events.request.add_listener
def on_request(request_type, name, response_time, response_length, exception, **kwargs):
    """Track custom metrics for streaming requests"""
    global request_count, total_chunks

    if request_type == "POST" and "Claude Code Chat" in name:
        request_count += 1

        # Estimate chunks based on response length (rough approximation)
        estimated_chunks = response_length // 100 if response_length > 0 else 0
        total_chunks += estimated_chunks

        if request_count % 50 == 0:
            avg_chunks = total_chunks / request_count if request_count > 0 else 0
            print(
                f"\n[Metrics] {request_count} requests processed, "
                f"avg {avg_chunks:.1f} chunks per response"
            )
