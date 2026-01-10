import json 
import boto3 
import os 
import uuid 

s3_client = boto3.client('s3', region_name=os.environ['REGION'])
BUCKET = os.environ['RAW_BUCKET']

def handler (event, context): 
    """Generate Presigned URL for uploading video to S3"""
    try: 
        body = json.loads(event.get('body', '{}'))
        filename = body.get('filename', 'video.mp4')
        content_type = body.get('content_type', 'video/mp4')
        #Generate Unique key to avoid collisions
        file_ext = filename.split('.')[-1] if '.' in filename else 'mp4'
        unique_id = str(uuid.uuid4())[:8]
        key = f"uploads/{unique_id}-{filename}"
        #Generate presigned URL (10 minutes valid)
        presigned_url = s3_client.generate_presigned_url( 
            'put_object',
            Params={ 
                'Bucket': BUCKET,
                'Key' : key,
                'ContentType' : content_type
            },
            ExpiresIn=600
        )
        preview_url = s3_client.generate_presigned_url( 
            'get_object',
            Params={ 
                'Bucket': BUCKET,
                'Key': key
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
                'upload_url': presigned_url,
                'key': key,
                'expires_in': 600,
                'preview_url': preview_url
            })
        }
    except Exception as e: 
        return { 
            'statusCode': 500,
            'headers': { 
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({ 'error': str(e)})
        }
