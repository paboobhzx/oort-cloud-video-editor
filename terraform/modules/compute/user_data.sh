#!/bin/bash
set -e

########################################
# Basic system setup
########################################
dnf update -y

########################################
# Install jq (from Amazon Linux repo)
########################################
dnf install -y jq

########################################
# Install ffmpeg (static, from S3)
########################################
ARCH=$(uname -m)
cd /tmp

if [ "$ARCH" = "x86_64" ]; then
  aws s3 cp s3://${raw_videos_bucket}/dependencies/ffmpeg-amd64.tar.xz ffmpeg.tar.xz --region ${aws_region}
elif [ "$ARCH" = "aarch64" ]; then
  aws s3 cp s3://${raw_videos_bucket}/dependencies/ffmpeg-arm64.tar.xz ffmpeg.tar.xz --region ${aws_region}
else
  echo "Unsupported architecture: $ARCH"
  exit 1
fi

tar xf ffmpeg.tar.xz
cd ffmpeg-git-*-static
install -m 0755 ffmpeg ffprobe /usr/local/bin/
cd /
rm -rf /tmp/ffmpeg*

########################################
# Application directory
########################################
mkdir -p /opt/video-processor

########################################
# Environment file (THIS IS THE KEY FIX)
########################################
cat > /etc/video-processor.env <<EOF
SQS_QUEUE_URL=${sqs_queue_url}
RAW_BUCKET=${raw_videos_bucket}
PROCESSED_BUCKET=${processed_videos_bucket}
AWS_REGION=${aws_region}
EOF

chmod 600 /etc/video-processor.env

########################################
# Worker script
########################################
cat > /opt/video-processor/worker.sh <<'EOF'
#!/bin/bash
set -euo pipefail

echo "$(date): Worker started"

while true; do
  MESSAGE=$(aws sqs receive-message \
    --queue-url "$SQS_QUEUE_URL" \
    --max-number-of-messages 1 \
    --wait-time-seconds 20 \
    --visibility-timeout 1800 \
    --region "$AWS_REGION")

  RECEIPT=$(echo "$MESSAGE" | jq -r '.Messages[0].ReceiptHandle // empty')
  BODY=$(echo "$MESSAGE" | jq -r '.Messages[0].Body // empty')

  if [ -z "$RECEIPT" ]; then
    sleep 5
    continue
  fi

  EVENT=$(echo "$BODY" | jq -r '.Event // empty')
  if [ "$EVENT" = "s3:TestEvent" ]; then
    aws sqs delete-message \
      --queue-url "$SQS_QUEUE_URL" \
      --receipt-handle "$RECEIPT" \
      --region "$AWS_REGION"
    continue
  fi

  KEY=$(echo "$BODY" | jq -r '.Records[0].s3.object.key // empty')
  if [ -z "$KEY" ]; then
    aws sqs delete-message \
      --queue-url "$SQS_QUEUE_URL" \
      --receipt-handle "$RECEIPT" \
      --region "$AWS_REGION"
    continue
  fi

KEY=$(printf '%b' "$${KEY//%/\\x}")

  WORKDIR="/tmp/job-$(date +%s)"
  mkdir -p "$WORKDIR"

  aws s3 cp "s3://$RAW_BUCKET/$KEY" "$WORKDIR/input.mp4" --region "$AWS_REGION"
  cp "$WORKDIR/input.mp4" "$WORKDIR/output.mp4"
  aws s3 cp "$WORKDIR/output.mp4" "s3://$PROCESSED_BUCKET/processed-$(basename "$KEY")" --region "$AWS_REGION"

  aws sqs delete-message \
    --queue-url "$SQS_QUEUE_URL" \
    --receipt-handle "$RECEIPT" \
    --region "$AWS_REGION"

  rm -rf "$WORKDIR"
done
EOF

chmod +x /opt/video-processor/worker.sh

########################################
# systemd service
########################################
cat > /etc/systemd/system/video-processor.service <<EOF
[Unit]
Description=Video Processor Worker
After=network.target

[Service]
Type=simple
User=root
EnvironmentFile=/etc/video-processor.env
ExecStart=/opt/video-processor/worker.sh
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

########################################
# Start service
########################################
systemctl daemon-reload
systemctl enable video-processor.service
systemctl start video-processor.service

echo "$(date): Video processor setup complete"
