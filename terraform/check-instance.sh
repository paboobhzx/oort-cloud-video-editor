#!/bin/bash

echo "⏳ Waiting for EC2 instance to launch..."
echo "This takes 1-3 minutes. Checking every 10 seconds..."
echo ""

for attempt in {1..18}; do
    echo "Attempt $attempt/18..."
    
    instance_info=$(aws autoscaling describe-auto-scaling-groups \
      --auto-scaling-group-names oort-cloud-video-editor-dev-processor-asg \
      --query 'AutoScalingGroups[0].Instances[0].[InstanceId,LifecycleState,HealthStatus]' \
      --output text)
    
    if [ ! -z "$instance_info" ] && [ "$instance_info" != "None" ]; then
        instance_id=$(echo $instance_info | awk '{print $1}')
        lifecycle_state=$(echo $instance_info | awk '{print $2}')
        health_status=$(echo $instance_info | awk '{print $3}')
        
        echo "  Instance ID: $instance_id"
        echo "  Lifecycle: $lifecycle_state"
        echo "  Health: $health_status"
        
        if [ "$lifecycle_state" == "InService" ]; then
            echo ""
            echo "✅ Instance is InService!"
            echo "export INSTANCE_ID=$instance_id" > /tmp/instance_id.sh
            export INSTANCE_ID=$instance_id
            echo "Instance ID saved: $INSTANCE_ID"
            break
        fi
    else
        echo "  No instance found yet..."
    fi
    
    if [ $attempt -lt 18 ]; then
        sleep 10
    fi
done

echo ""
echo "Current INSTANCE_ID: $INSTANCE_ID"
