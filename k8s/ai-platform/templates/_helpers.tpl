{{/*
Expand the name of the chart.
*/}}
{{- define "ai-platform.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
Uses release name directly so services are named <release>-<component>.
*/}}
{{- define "ai-platform.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "ai-platform.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "ai-platform.labels" -}}
helm.sh/chart: {{ include "ai-platform.chart" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Component-specific labels
*/}}
{{- define "ai-platform.componentLabels" -}}
{{ include "ai-platform.labels" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
LiteLLM Control Plane selector labels
*/}}
{{- define "ai-platform.litellm-control.selectorLabels" -}}
app.kubernetes.io/name: litellm-control
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
LiteLLM Data Plane selector labels
*/}}
{{- define "ai-platform.litellm-data.selectorLabels" -}}
app.kubernetes.io/name: litellm-data
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
LiteLLM selector labels (legacy - kept for backwards compatibility)
*/}}
{{- define "ai-platform.litellm.selectorLabels" -}}
app.kubernetes.io/name: litellm
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Open-WebUI selector labels
*/}}
{{- define "ai-platform.openWebui.selectorLabels" -}}
app.kubernetes.io/name: open-webui
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
vLLM selector labels
*/}}
{{- define "ai-platform.vllm.selectorLabels" -}}
app.kubernetes.io/name: vllm
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
MCP SearXNG selector labels
*/}}
{{- define "ai-platform.mcpSearxng.selectorLabels" -}}
app.kubernetes.io/name: mcp-searxng
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Benchmark perf-viewer selector labels
*/}}
{{- define "ai-platform.benchmarkPerfViewer.selectorLabels" -}}
app.kubernetes.io/name: benchmark-perf-viewer
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Benchmark eval-viewer selector labels
*/}}
{{- define "ai-platform.benchmarkEvalViewer.selectorLabels" -}}
app.kubernetes.io/name: benchmark-eval-viewer
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Benchmark run ID. Set per-run by run-benchmark.sh; falls back to the release
revision so `helm template` still renders a stable name.
*/}}
{{- define "ai-platform.benchmark.runId" -}}
{{- .Values.benchmark.runId | default (printf "rev-%d" (.Release.Revision | int)) }}
{{- end }}

{{/*
Benchmark eval-viewer image: explicit override, else the runner image
(which already has inspect-ai installed).
*/}}
{{- define "ai-platform.benchmark.evalViewerImage" -}}
{{- if .Values.benchmark.viewers.evals.image }}
{{- .Values.benchmark.viewers.evals.image }}
{{- else }}
{{- printf "%s:%s" .Values.benchmark.runnerImage.repository .Values.benchmark.runnerImage.tag }}
{{- end }}
{{- end }}

{{/*
In-cluster base URLs for the benchmark targets. Derived from the release name so
they follow whatever this chart actually deployed, rather than being hardcoded.
*/}}
{{- define "ai-platform.benchmark.vllmBaseUrl" -}}
{{- printf "http://%s-vllm.%s.svc.cluster.local:%v/v1" (include "ai-platform.fullname" .) .Release.Namespace .Values.vllm.service.port }}
{{- end }}

{{- define "ai-platform.benchmark.litellmBaseUrl" -}}
{{- printf "http://%s-litellm-data.%s.svc.cluster.local:%v/v1" (include "ai-platform.fullname" .) .Release.Namespace .Values.litellm.service.port }}
{{- end }}
