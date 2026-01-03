#!/bin/bash
set -e

# Update system
yum update -y

# Install FFmpeg (from EPEL repository)
amazon-linux-extras install epel -y
yum install -y ffmpeg

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

# Install jq for JSON parsing
yum install -y jq

# Create working directory
mkdir -p /opt/video-processor
cd /opt/video-processor

# Environment variables (will be replaced by Terraform)
export SQS_QUEUE_URL="${sqs_queue_url}"
export RAW_BUCKET="${raw_videos_bucket}"
export PROCESSED_BUCKET="${processed_videos_bucket}"
export AWS_REGION="${aws_region}"

# Create spot interruption handler
cat > /opt/video-processor/spot-handler.sh <<'SPOT_HANDLER'
#!/bin/bash
while true; do
  # Check for spot termination notice (2 min warning)
  if curl -sf http://169.254.169.254/latest/meta-data/spot/instance-action 2>/dev/null; then
    echo "$(date): Spot termination notice received. Graceful shutdown..."
    
    # Return current SQS message to queue if processing
    if [ ! -z "$CURRENT_RECEIPT_HANDLE" ]; then
      aws sqs change-message-visibility \
        --queue-url $SQS_QUEUE_URL \
        --receipt-handle $CURRENT_RECEIPT_HANDLE \
        --visibility-timeout 0 \
        --region $AWS_REGION
    fi
    
    # Cleanup
    rm -rf /tmp/video-*
    echo "$(date): Cleanup complete. Exiting..."
    exit 0
  fi
  sleep 5
done
SPOT_HANDLER

chmod +x /opt/video-processor/spot-handler.sh

# Create video processing script
cat > /opt/video-processor/process-video.sh <<'PROCESS_SCRIPT'
#!/bin/bash
set -e

VIDEO_KEY=$1
OPERATIONS=$2

echo "$(date): Processing video: $VIDEO_KEY"
echo "$(date): Operations: $OPERATIONS"

# Generate unique ID for this job
JOB_ID=$(echo $VIDEO_KEY | md5sum | cut -d' ' -f1)
WORK_DIR="/tmp/video-$JOB_ID"
mkdir -p $WORK_DIR

# Download video from S3
INPUT_FILE="$WORK_DIR/input.mp4"
echo "$(date): Downloading from S3..."
aws s3 cp "s3://$RAW_BUCKET/$VIDEO_KEY" "$INPUT_FILE" --region $AWS_REGION

# Get video info
DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$INPUT_FILE")
echo "$(date): Video duration: $DURATION seconds"

# Parse operations (JSON format)
OUTPUT_FILE="$WORK_DIR/output.mp4"

# Example FFmpeg command (we'll expand this later)
# For now, just copy the file as a test
cp "$INPUT_FILE" "$OUTPUT_FILE"

# TODO: Add actual FFmpeg operations based on $OPERATIONS JSON
# - Resample
# - Trim
# - Watermark
# - etc.

# Upload processed video to S3
OUTPUT_KEY="processed-$(basename $VIDEO_KEY)"
echo "$(date): Uploading to S3..."
aws s3 cp "$OUTPUT_FILE" "s3://$PROCESSED_BUCKET/$OUTPUT_KEY" --region $AWS_REGION

# Generate presigned URL (5 minutes expiry)
DOWNLOAD_URL=$(aws s3 presign "s3://$PROCESSED_BUCKET/$OUTPUT_KEY" --expires-in 300 --region $AWS_REGION)
echo "$(date): Download URL: $DOWNLOAD_URL"

# Cleanup
rm -rf $WORK_DIR
echo "$(date): Processing complete!"
PROCESS_SCRIPT

chmod +x /opt/video-processor/process-video.sh

# Create main worker loop
cat > /opt/video-processor/worker.sh <<'WORKER_SCRIPT'
#!/bin/bash
set -e

echo "$(date): Video processor worker started"
echo "$(date): SQS Queue: $SQS_QUEUE_URL"
echo "$(date): Raw Bucket: $RAW_BUCKET"
echo "$(date): Processed Bucket: $PROCESSED_BUCKET"

while true; do
  # Poll SQS for jobs
  MESSAGE=$(aws sqs receive-message \
    --queue-url $SQS_QUEUE_URL \
    --max-number-of-messages 1 \
    --visibility-timeout 300 \
    --wait-time-seconds 20 \
    --region $AWS_REGION 2>/dev/null || echo "")
  
  if [ -z "$MESSAGE" ] || [ "$MESSAGE" == "null" ]; then
    echo "$(date): No messages in queue. Waiting..."
    sleep 10
    continue
  fi
  
  # Parse message
  RECEIPT_HANDLE=$(echo $MESSAGE | jq -r '.Messages[0].ReceiptHandle')
  BODY=$(echo $MESSAGE | jq -r '.Messages[0].Body')
  
  if [ "$RECEIPT_HANDLE" == "null" ]; then
    echo "$(date): Invalid message. Skipping..."
    sleep 5
    continue
  fi
  
  # Export receipt handle for spot handler
  export CURRENT_RECEIPT_HANDLE=$RECEIPT_HANDLE
  
  echo "$(date): Received job from SQS"
  
  # Parse S3 event notification
  VIDEO_KEY=$(echo $BODY | jq -r '.Records[0].s3.object.key')
  
  if [ "$VIDEO_KEY" == "null" ]; then
    echo "$(date): Invalid S3 event. Deleting message..."
    aws sqs delete-message \
      --queue-url $SQS_QUEUE_URL \
      --receipt-handle $RECEIPT_HANDLE \
      --region $AWS_REGION
    continue
  fi
  
  echo "$(date): Processing video: $VIDEO_KEY"
  
  # Process video (with error handling)
  if /opt/video-processor/process-video.sh "$VIDEO_KEY" "{}"; then
    echo "$(date): Processing successful. Deleting message from queue..."
    aws sqs delete-message \
      --queue-url $SQS_QUEUE_URL \
      --receipt-handle $RECEIPT_HANDLE \
      --region $AWS_REGION
  else
    echo "$(date): Processing failed. Message will return to queue..."
  fi
  
  # Clear receipt handle
  unset CURRENT_RECEIPT_HANDLE
done
WORKER_SCRIPT

chmod +x /opt/video-processor/worker.sh

# Create systemd service for worker
cat > /etc/systemd/system/video-processor.service <<SERVICE
[Unit]
Description=Video Processor Worker
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/video-processor
Environment="SQS_QUEUE_URL=${sqs_queue_url}"
Environment="RAW_BUCKET=${raw_videos_bucket}"
Environment="PROCESSED_BUCKET=${processed_videos_bucket}"
Environment="AWS_REGION=${aws_region}"
ExecStart=/opt/video-processor/worker.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SERVICE

# Create systemd service for spot handler
cat > /etc/systemd/system/spot-handler.service <<SPOT_SERVICE
[Unit]
Description=Spot Instance Interruption Handler
After=network.target

[Service]
Type=simple
User=root
Environment="SQS_QUEUE_URL=${sqs_queue_url}"
Environment="AWS_REGION=${aws_region}"
ExecStart=/opt/video-processor/spot-handler.sh
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SPOT_SERVICE

# Enable and start services
systemctl daemon-reload
systemctl enable video-processor.service
systemctl start video-processor.service
systemctl enable spot-handler.service
systemctl start spot-handler.service

echo "$(date): Video processor setup complete!"