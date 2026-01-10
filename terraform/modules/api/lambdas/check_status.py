import json
import boto3
import os
from botocore.exceptions import ClientError

s3 = boto3.client("s3", region_name=os.environ["REGION"])
BUCKET = os.environ["PROCESSED_BUCKET"]

def handler(event, context):
    params = event.get("queryStringParameters") or {}
    output_key = params.get("output_key")

    if not output_key:
        return response(400, {"error": "Missing output_key"})

    try:
        s3.head_object(Bucket=BUCKET, Key=output_key)

        # ✅ FILE EXISTS
        return response(200, {
            "status": "completed",
            "output_key": output_key
        })

    except ClientError as e:
        if e.response["Error"]["Code"] == "404":
            return response(200, {
                "status": "processing",
                "output_key": output_key
            })

        # other error
        return response(500, {"error": str(e)})


def response(code, body):
    return {
        "statusCode": code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*"
        },
        "body": json.dumps(body)
    }
