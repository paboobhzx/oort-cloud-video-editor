import json
import boto3
import os

s3_client = boto3.client('s3', region_name=os.environ['REGION'])
BUCKET = os.environ['PROCESSED_BUCKET']

def handler(event, context):
    """Generate presigned URL for downloading processed video from S3"""
    try:
        # Get output_key from query string
        query_params = event.get('queryStringParameters', {}) or {}
        output_key = query_params.get('output_key')
        
        if not output_key:
            return {
                'statusCode': 400,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({'error': 'Missing required parameter: output_key'})
            }
        
        # Check if file exists first
        try:
            s3_client.head_object(Bucket=BUCKET, Key=output_key)
        except s3_client.exceptions.ClientError as e:
            if e.response['Error']['Code'] == '404':
                return {
                    'statusCode': 404,
                    'headers': {
                        'Content-Type': 'application/json',
                        'Access-Control-Allow-Origin': '*'
                    },
                    'body': json.dumps({'error': 'File not found', 'output_key': output_key})
                }
            raise
        
        # Generate presigned URL (valid for 1 hour)
        presigned_url = s3_client.generate_presigned_url(
            'get_object',
            Params={
                'Bucket': BUCKET,
                'Key': output_key
            },
            ExpiresIn=3600
        )
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'download_url': presigned_url,
                'output_key': output_key,
                'expires_in': 3600
            })
        }
        
    except Exception as e:
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({'error': str(e)})
        }