import json
import boto3
import os
import uuid

sqs_client = boto3.client('sqs', region_name=os.environ['REGION'])
QUEUE_URL = os.environ['SQS_QUEUE_URL']

def handler(event, context):
    """Submit a video processing job to SQS"""
    try:
        body = json.loads(event.get('body', '{}'))
        
        # Required fields
        input_key = body.get('input_key')
        operation = body.get('operation')
        
        if not input_key or operation is None:
            return {
                'statusCode': 400,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({'error': 'Missing required fields: input_key, operation'})
            }
        
        # Optional fields
        params = body.get('params', {})
        output_key = body.get('output_key')
        
        # Generate job ID for tracking
        job_id = str(uuid.uuid4())
        
        # Build message
        message = {
            'job_id': job_id,
            'operation': operation,
            'input_key': input_key,
            'params': params
        }
        
        if output_key:
            message['output_key'] = output_key
        
        # Send to SQS
        response = sqs_client.send_message(
            QueueUrl=QUEUE_URL,
            MessageBody=json.dumps(message)
        )
        
        # Predict output key (same logic as worker)
        if not output_key:
            filename = input_key.split('/')[-1]
            name_parts = filename.rsplit('.', 1)
            base_name = name_parts[0]
            ext = name_parts[1] if len(name_parts) > 1 else 'mp4'
            
            # Adjust extension based on operation
            if operation == 5:
                ext = 'jpg'
            elif operation == 6:
                ext = 'mp3'
            
            output_key = f"processed/{base_name}_op{operation}.{ext}"
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'job_id': job_id,
                'message_id': response['MessageId'],
                'input_key': input_key,
                'output_key': output_key,
                'operation': operation,
                'status': 'queued'
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