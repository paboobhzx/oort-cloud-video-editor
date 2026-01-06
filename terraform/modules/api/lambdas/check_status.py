import json
import boto3
import os

s3_client = boto3.client("s3", region_name=os.environ["REGION"])
BUCKET = os.environ["PROCESSED_BUCKET"]

def handler(event, context):
    """Check if processed file exists in S3"""
    try:
        query_params = event.get("queryStringParameters") or {}
        output_key = query_params.get("output_key")

        if not output_key:
            return {
                "statusCode": 400,
                "headers": {
                    "Content-Type": "application/json",
                    "Access-Control-Allow-Origin": "*"
                },
                "body": json.dumps({
                    "error": "Missing required parameter: output_key"
                })
            }

        try:
            s3_client.head_object(Bucket=BUCKET, Key=output_key)
            return {
                "statusCode": 200,
                "headers": {
                    "Content-Type": "application/json",
                    "Access-Control-Allow-Origin": "*"
                },
                "body": json.dumps({
                    "status": "completed",
                    "output_key": output_key
                })
            }

        except s3_client.exceptions.ClientError as e:
            if e.response["Error"]["Code"] == "404":
                return {
                    "statusCode": 200,
                    "headers": {
                        "Content-Type": "application/json",
                        "Access-Control-Allow-Origin": "*"
                    },
                    "body": json.dumps({
                        "status": "processing",
                        "output_key": output_key
                    })
                }
            raise

    except Exception as e:
        return {
            "statusCode": 500,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*"
            },
            "body": json.dumps({"error": str(e)})
        }
