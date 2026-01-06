#!/bin/bash
set -euo pipefail

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1"
}

error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1" >&2
}

warn() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] $1" >&2
}

log "Worker started"
log "SQS_QUEUE_URL: $SQS_QUEUE_URL"
log "RAW_BUCKET: $RAW_BUCKET"
log "PROCESSED_BUCKET: $PROCESSED_BUCKET"
log "AWS_REGION: $AWS_REGION"

if ! command -v ffmpeg &> /dev/null; then
    error "ffmpeg not found!"
    exit 1
fi
log "FFmpeg version: $(ffmpeg -version | head -1)"

while true; do
    log "Polling SQS for messages..."
    
    MESSAGE=$(aws sqs receive-message \
        --queue-url "$SQS_QUEUE_URL" \
        --max-number-of-messages 1 \
        --wait-time-seconds 20 \
        --visibility-timeout 1800 \
        --region "$AWS_REGION" 2>&1) || {
        error "Failed to receive SQS message: $MESSAGE"
        sleep 5
        continue
    }

    RECEIPT=$(echo "$MESSAGE" | jq -r '.Messages[0].ReceiptHandle // empty')
    BODY=$(echo "$MESSAGE" | jq -r '.Messages[0].Body // empty')

    if [[ -z "$RECEIPT" ]]; then
        log "No messages in queue, waiting..."
        sleep 5
        continue
    fi

    log "Received message"
    log "Message body: $BODY"

    # Check for S3 test event
    EVENT=$(echo "$BODY" | jq -r '.Event // empty')
    if [[ "$EVENT" == "s3:TestEvent" ]]; then
        log "Skipping S3 test event"
        aws sqs delete-message \
            --queue-url "$SQS_QUEUE_URL" \
            --receipt-handle "$RECEIPT" \
            --region "$AWS_REGION"
        continue
    fi

    # Check if this is a custom job message (has "operation" field)
    OPERATION=$(echo "$BODY" | jq -r '.operation // empty')
    
    if [[ -n "$OPERATION" ]]; then
        # Custom job message format
        log "Processing custom job - Operation: $OPERATION"
        
        INPUT_KEY=$(echo "$BODY" | jq -r '.input_key // empty')
        OUTPUT_KEY=$(echo "$BODY" | jq -r '.output_key // empty')
        PARAMS=$(echo "$BODY" | jq -r '.params // {}')
        
        if [[ -z "$INPUT_KEY" ]]; then
            error "Missing input_key in job message"
            aws sqs delete-message \
                --queue-url "$SQS_QUEUE_URL" \
                --receipt-handle "$RECEIPT" \
                --region "$AWS_REGION"
            continue
        fi
        
        # Generate output key if not provided
        if [[ -z "$OUTPUT_KEY" ]]; then
            BASENAME=$(basename "$INPUT_KEY")
            FILENAME="${BASENAME%.*}"
            EXT="${BASENAME##*.}"
            
            # Determine output extension based on operation
            case "$OPERATION" in
                5) OUTPUT_EXT="jpg" ;;   # Thumbnail
                6) OUTPUT_EXT="mp3" ;;   # Audio extraction
                *) OUTPUT_EXT="$EXT" ;;  # Keep original extension
            esac
            
            OUTPUT_KEY="processed/${FILENAME}_op${OPERATION}.${OUTPUT_EXT}"
        fi
        
        log "Input key: $INPUT_KEY"
        log "Output key: $OUTPUT_KEY"
        log "Params: $PARAMS"
        
    else
        # S3 notification format (legacy - passthrough)
        KEY=$(echo "$BODY" | jq -r '.Records[0].s3.object.key // empty')
        
        if [[ -z "$KEY" ]]; then
            warn "No valid key found in message, deleting"
            aws sqs delete-message \
                --queue-url "$SQS_QUEUE_URL" \
                --receipt-handle "$RECEIPT" \
                --region "$AWS_REGION"
            continue
        fi
        
        # URL decode the key
        KEY=$(printf '%b' "${KEY//%/\\x}")
        
        log "Processing S3 notification for: $KEY (passthrough)"
        
        OPERATION=0
        INPUT_KEY="$KEY"
        OUTPUT_KEY="processed-$(basename "$KEY")"
        PARAMS="{}"
    fi

    # Create working directory
    WORKDIR="/tmp/job-$(date +%s)-$$"
    mkdir -p "$WORKDIR"
    log "Work directory: $WORKDIR"
    
    INPUT_BASENAME=$(basename "$INPUT_KEY")
    INPUT_FILE="$WORKDIR/$INPUT_BASENAME"
    OUTPUT_BASENAME=$(basename "$OUTPUT_KEY")
    OUTPUT_FILE="$WORKDIR/$OUTPUT_BASENAME"

    # Download input file from S3
    log "Downloading s3://$RAW_BUCKET/$INPUT_KEY"
    if ! aws s3 cp "s3://$RAW_BUCKET/$INPUT_KEY" "$INPUT_FILE" --region "$AWS_REGION" 2>&1; then
        error "Failed to download input file"
        rm -rf "$WORKDIR"
        continue
    fi
    log "Downloaded $(stat -c%s "$INPUT_FILE" 2>/dev/null || echo "unknown") bytes"

    # Process based on operation
    PROCESS_SUCCESS=true
    
    case "$OPERATION" in
        0)
            # Passthrough - just copy
            log "Operation 0: Passthrough (copy)"
            cp "$INPUT_FILE" "$OUTPUT_FILE"
            ;;
        
        1)
            # Resize
            WIDTH=$(echo "$PARAMS" | jq -r '.width // 1280')
            HEIGHT=$(echo "$PARAMS" | jq -r '.height // 720')
            log "Operation 1: Resize to ${WIDTH}x${HEIGHT}"
            /opt/video-processor/ffmpeg_runner.sh 1 "$INPUT_FILE" "$OUTPUT_FILE" "$WIDTH" "$HEIGHT" || PROCESS_SUCCESS=false
            ;;
        
        2)
            # Cut/Trim
            START=$(echo "$PARAMS" | jq -r '.start // "00:00:00"')
            DURATION=$(echo "$PARAMS" | jq -r '.duration // "00:00:10"')
            log "Operation 2: Cut from $START for $DURATION"
            /opt/video-processor/ffmpeg_runner.sh 2 "$INPUT_FILE" "$OUTPUT_FILE" "$START" "$DURATION" || PROCESS_SUCCESS=false
            ;;
        
        3)
            # Speed change
            SPEED=$(echo "$PARAMS" | jq -r '.speed // 1.0')
            log "Operation 3: Speed change to ${SPEED}x"
            /opt/video-processor/ffmpeg_runner.sh 3 "$INPUT_FILE" "$OUTPUT_FILE" "$SPEED" || PROCESS_SUCCESS=false
            ;;
        
        4)
            # Framerate change
            FPS=$(echo "$PARAMS" | jq -r '.fps // 30')
            log "Operation 4: Change framerate to $FPS"
            /opt/video-processor/ffmpeg_runner.sh 4 "$INPUT_FILE" "$OUTPUT_FILE" "$FPS" || PROCESS_SUCCESS=false
            ;;
        
        5)
            # Extract thumbnail
            TIMESTAMP=$(echo "$PARAMS" | jq -r '.timestamp // "00:00:01"')
            log "Operation 5: Extract thumbnail at $TIMESTAMP"
            /opt/video-processor/ffmpeg_runner.sh 5 "$INPUT_FILE" "$OUTPUT_FILE" "$TIMESTAMP" || PROCESS_SUCCESS=false
            ;;
        
        6)
            # Extract audio
            BITRATE=$(echo "$PARAMS" | jq -r '.bitrate // "192k"')
            log "Operation 6: Extract audio at $BITRATE"
            /opt/video-processor/ffmpeg_runner.sh 6 "$INPUT_FILE" "$OUTPUT_FILE" "$BITRATE" || PROCESS_SUCCESS=false
            ;;
        
        *)
            error "Unknown operation: $OPERATION"
            PROCESS_SUCCESS=false
            ;;
    esac

    if [[ "$PROCESS_SUCCESS" == "true" && -f "$OUTPUT_FILE" ]]; then
        log "Uploading to s3://$PROCESSED_BUCKET/$OUTPUT_KEY"
        if aws s3 cp "$OUTPUT_FILE" "s3://$PROCESSED_BUCKET/$OUTPUT_KEY" --region "$AWS_REGION" 2>&1; then
            log "Upload successful"
            
            aws sqs delete-message \
                --queue-url "$SQS_QUEUE_URL" \
                --receipt-handle "$RECEIPT" \
                --region "$AWS_REGION"
            log "Message deleted from queue"
        else
            error "Failed to upload output file"
        fi
    else
        error "Processing failed or output file not created"
    fi

    rm -rf "$WORKDIR"
    log "Cleanup complete"
    log "---"
done