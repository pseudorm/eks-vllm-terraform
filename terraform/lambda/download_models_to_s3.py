import requests
import boto3
import logging
from urllib.parse import urlsplit

logging.basicConfig(level=logging.INFO)

logger = logging.getLogger()
logger.setLevel(logging.INFO)

HUGGINGFACE_BASE_URL = ""
CHUNK_SIZE = 6 * 1024 * 1024  # 6MB

s3_client = boto3.client("s3")


def stream_download_into_s3_bucket(
    url: str, bucket_name: str, prefix: str = "", chunk_size: int = CHUNK_SIZE
) -> None:
    filename = urlsplit(url).path
    key = f"{prefix}/{filename}"

    multiple_upload = s3_client.create_multipart_upload(Bucket=bucket_name, Key=key)
    upload_id = multiple_upload["UploadId"]

    response = requests.get(url, stream=True, timeout=30)
    response.raise_for_status()

    part_number = 1
    parts = []

    try:
        for chunk in response.iter_content(chunk_size=chunk_size):
            logger.info(
                "Downloaded and uploaded %d Mb",
                part_number * CHUNK_SIZE / (1024 * 1024),
            )
            part = s3_client.upload_part(
                Bucket=bucket_name,
                Key=key,
                UploadId=upload_id,
                PartNumber=part_number,
                Body=chunk,
            )
            parts.append({"ETag": part["ETag"], "PartNumber": part_number})
            part_number += 1

        s3_client.complete_multipart_upload(
            Bucket=bucket_name,
            Key=key,
            UploadId=upload_id,
            MultipartUpload={"Parts": parts},
        )
    except Exception as e:
        logger.error(
            "Critical error occured during streaming download to S3 bucket, aborting. %s",
            str(e),
        )
        s3_client.abort_multipart_upload(
            Bucket=bucket_name, Key=key, UploadId=upload_id
        )


def download_model_weights_from_huggingface(model_id: str) -> None: ...


def lambda_handler(event, context):
    model_id = event.get("model_id", "")
    url = event.get("url", "")
    s3_bucket = event.get("target_bucket_name")
    s3_prefix = event.get("storage_prefix", "")

    if not s3_bucket:
        raise ValueError("`target_bucket_name` must be provided.")

    if not (model_id or url):
        raise ValueError(
            "One of `url` or `model_id` must be provided. "
            "Otherwise there's nothing to download."
        )

    logger.info("Downloading model %s from huggingface", model_id)

    if url:
        stream_download_into_s3_bucket(url, s3_bucket, s3_prefix)


def parse_args():
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument("--url", default=None, required=False)
    parser.add_argument("--s3_bucket", default=None, required=False)
    parser.add_argument("--s3_prefix", default=None, required=False)

    args = parser.parse_args()

    return args


if __name__ == "__main__":
    args = parse_args()
    lambda_handler(
        {
            "url": args.url,
            "target_bucket_name": args.s3_bucket,
            "storage_prefix": args.s3_prefix,
        },
        None,
    )
