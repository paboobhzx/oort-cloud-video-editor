#!/bin/bash

if [ -f /tmp/instance_id.sh ]; then
    source /tmp/instance_id.sh
fi

if [ -z "$INSTANCE_ID" ]; then
    echo "❌ ERROR: INSTANCE_ID is not set"
    echo "Run ./check-instance.sh first"
    exit 1
fi

echo "📋 Fetching console output for instance: $INSTANCE_ID"
echo ""

output=$(aws ec2 get-console-output --instance-id $INSTANCE_ID --query 'Output' --output text 2>/dev/null)

if [ -z "$output" ] || [ "$output" == "None" ]; then
    echo "⚠️  Console output not available yet"
    echo "Wait 2-3 more minutes and run this script again"
else
    echo "✅ Console output available!"
    echo ""
    echo "=== Last 100 Lines ==="
    echo "$output" | tail -100
fi
