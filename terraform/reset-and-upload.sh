#!/bin/bash

echo "🛑 Step 1: Shutting down all instances in ASG..."
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name oort-cloud-video-editor-dev-processor-asg \
  --desired-capacity 0

echo "⏳ Waiting 30 seconds for instances to terminate..."
sleep 30

echo ""
echo "🗑️  Step 2: Purging SQS queue..."
aws sqs purge-queue --queue-url $SQS_URL

echo "⏳ Waiting 60 seconds for purge to complete..."
sleep 60

echo ""
echo "✅ Step 3: Verifying no instances are running..."
instance_count=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names oort-cloud-video-editor-dev-processor-asg \
  --query 'AutoScalingGroups[0].Instances | length(@)' \
  --output text)

if [ "$instance_count" -eq 0 ]; then
    echo "✅ No instances running"
else
    echo "⚠️  Warning: $instance_count instance(s) still running"
    echo "Instances:"
    aws autoscaling describe-auto-scaling-groups \
      --auto-scaling-group-names oort-cloud-video-editor-dev-processor-asg \
      --query 'AutoScalingGroups[0].Instances[*].[InstanceId,LifecycleState]' \
      --output table
fi

echo ""
echo "📤 Step 4: Uploading test01.mp4 to raw bucket..."
if [ -f "test01.mp4" ]; then
    aws s3 cp test01.mp4 s3://$RAW_BUCKET/test01.mp4
    echo "✅ Upload complete: test01.mp4"
else
    echo "❌ Error: test01.mp4 not found in current directory"
    echo "Creating a test file..."
    echo "Test video $(date)" > test01.mp4
    aws s3 cp test01.mp4 s3://$RAW_BUCKET/test01.mp4
    echo "✅ Created and uploaded test01.mp4"
fi

echo ""
echo "🎯 Summary:"
echo "  - ASG desired capacity: 0"
echo "  - SQS queue: purged"
echo "  - Instances running: $instance_count"
echo "  - Test video uploaded: test01.mp4"
echo ""
echo "✅ Ready for testing!"
