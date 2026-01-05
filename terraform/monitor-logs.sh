#!/bin/bash

if [ -f /tmp/instance_id.sh ]; then
    source /tmp/instance_id.sh
fi

if [ -z "$INSTANCE_ID" ]; then
    echo "❌ ERROR: INSTANCE_ID is not set"
    echo "Run ./check-instance.sh first"
    exit 1
fi

echo "🔄 Monitoring console output"
echo "Press Ctrl+C to stop"
echo ""

while true; do
    clear
    echo "=== Instance: $INSTANCE_ID ==="
    echo "=== Time: $(date) ==="
    echo ""
    
    aws ec2 get-console-output --instance-id $INSTANCE_ID --query 'Output' --output text 2>/dev/null | tail -50
    
    echo ""
    echo "Refreshing in 30 seconds..."
    sleep 30
done
