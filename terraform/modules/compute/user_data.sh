#!/bin/bash
#set -e

# Log everything
exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1
set -x

echo "===== USER DATA START $(date) ====="

echo "Ensuring SSM agent is running..."
systemctl enable amazon-ssm-agent
systemctl restart amazon-ssm-agent

sleep 10
systemctl status amazon-ssm-agent --no-pager || true

########################################
# Basic system setup
########################################
ARCH=$(uname -m)

########################################
# Install jq (from S3)
########################################
if [ "$ARCH" = "x86_64" ]; then
  aws s3 cp s3://${raw_videos_bucket}/dependencies/jq-amd64 /usr/local/bin/jq --region ${aws_region}
elif [ "$ARCH" = "aarch64" ]; then
  aws s3 cp s3://${raw_videos_bucket}/dependencies/jq-arm64 /usr/local/bin/jq --region ${aws_region}
fi
chmod +x /usr/local/bin/jq

########################################
# Install ffmpeg (static, from S3)
########################################
cd /tmp

if [ "$ARCH" = "x86_64" ]; then
  aws s3 cp s3://${raw_videos_bucket}/dependencies/ffmpeg-amd64.tar.xz ffmpeg.tar.xz --region ${aws_region}
  tar xf ffmpeg.tar.xz
  cd ffmpeg-*-amd64-static
elif [ "$ARCH" = "aarch64" ]; then
  aws s3 cp s3://${raw_videos_bucket}/dependencies/ffmpeg-arm64.tar.xz ffmpeg.tar.xz --region ${aws_region}
  tar xf ffmpeg.tar.xz
  cd ffmpeg-*-arm64-static
else
  echo "Unsupported architecture: $ARCH"
  exit 1
fi

install -m 0755 ffmpeg ffprobe /usr/local/bin/
cd /
rm -rf /tmp/ffmpeg*

########################################
# Application directory
########################################
mkdir -p /opt/video-processor
mkdir -p /var/log/video-processor

########################################
# Environment file
########################################
cat > /etc/video-processor.env <<EOF
SQS_QUEUE_URL=${sqs_queue_url}
RAW_BUCKET=${raw_videos_bucket}
PROCESSED_BUCKET=${processed_videos_bucket}
AWS_REGION=${aws_region}
EOF

chmod 600 /etc/video-processor.env

########################################
# Download worker scripts from S3
########################################
aws s3 cp s3://${raw_videos_bucket}/scripts/ffmpeg_runner.sh /opt/video-processor/ffmpeg_runner.sh --region ${aws_region}
aws s3 cp s3://${raw_videos_bucket}/scripts/worker.sh /opt/video-processor/worker.sh --region ${aws_region}

chmod +x /opt/video-processor/ffmpeg_runner.sh
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
StandardOutput=journal
StandardError=journal

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