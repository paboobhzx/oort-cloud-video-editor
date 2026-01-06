#!/bin/bash
#
# FFmpeg Runner - Video Processing Operations
# Usage: ffmpeg_runner.sh <operation> <input_file> <output_file> [params...]
#
# Operations:
#   1 = Resize video
#   2 = Cut/Trim video
#   3 = Change speed
#   4 = Change framerate
#   5 = Extract thumbnail (JPEG)
#   6 = Extract audio (MP3)
#

set -euo pipefail

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >&2
}

validate_input() {
    if [[ ! -f "$1" ]]; then
        error "Input file not found: $1"
        exit 1
    fi
}

OPERATION="${1:-}"
INPUT_FILE="${2:-}"
OUTPUT_FILE="${3:-}"

if [[ -z "$OPERATION" || -z "$INPUT_FILE" || -z "$OUTPUT_FILE" ]]; then
    error "Usage: ffmpeg_runner.sh <operation> <input_file> <output_file> [params...]"
    exit 1
fi

validate_input "$INPUT_FILE"

log "Starting operation $OPERATION"
log "Input: $INPUT_FILE"
log "Output: $OUTPUT_FILE"

case "$OPERATION" in

    # ============================================
    # 1 = Resize video
    # Params: width height
    # Example: ffmpeg_runner.sh 1 input.mp4 output.mp4 1280 720
    # ============================================
    1)
        WIDTH="${4:-1280}"
        HEIGHT="${5:-720}"
        log "Resizing to ${WIDTH}x${HEIGHT}"
        
        ffmpeg -y -i "$INPUT_FILE" \
            -vf "scale=${WIDTH}:${HEIGHT}:force_original_aspect_ratio=decrease,pad=${WIDTH}:${HEIGHT}:(ow-iw)/2:(oh-ih)/2" \
            -c:v libx264 -preset medium -crf 23 \
            -c:a aac -b:a 128k \
            "$OUTPUT_FILE" 2>&1
        
        log "Resize complete"
        ;;

    # ============================================
    # 2 = Cut/Trim video
    # Params: start_time duration
    # Time format: HH:MM:SS or seconds
    # Example: ffmpeg_runner.sh 2 input.mp4 output.mp4 00:00:10 00:00:30
    # ============================================
    2)
        START_TIME="${4:-00:00:00}"
        DURATION="${5:-00:00:10}"
        log "Cutting from $START_TIME for $DURATION"
        
        ffmpeg -y -i "$INPUT_FILE" \
            -ss "$START_TIME" -t "$DURATION" \
            -c:v libx264 -preset medium -crf 23 \
            -c:a aac -b:a 128k \
            "$OUTPUT_FILE" 2>&1
        
        log "Cut complete"
        ;;

    # ============================================
    # 3 = Change speed
    # Params: speed_factor (0.5 = half speed, 2.0 = double speed)
    # Example: ffmpeg_runner.sh 3 input.mp4 output.mp4 2.0
    # ============================================
    3)
        SPEED="${4:-1.0}"
        log "Changing speed to ${SPEED}x"
        
        # Calculate video PTS (inverse of speed) using awk
        VIDEO_PTS=$(awk "BEGIN {printf \"%.4f\", 1/$SPEED}")
        
        # Audio tempo filter - handle ranges with awk
        # atempo only accepts 0.5 to 2.0, so we chain if needed
        if awk "BEGIN {exit !($SPEED > 2.0)}"; then
            ATEMPO2=$(awk "BEGIN {printf \"%.4f\", $SPEED/2.0}")
            AUDIO_FILTER="atempo=2.0,atempo=$ATEMPO2"
        elif awk "BEGIN {exit !($SPEED < 0.5)}"; then
            ATEMPO2=$(awk "BEGIN {printf \"%.4f\", $SPEED/0.5}")
            AUDIO_FILTER="atempo=0.5,atempo=$ATEMPO2"
        else
            AUDIO_FILTER="atempo=$SPEED"
        fi
        
        ffmpeg -y -i "$INPUT_FILE" \
            -filter_complex "[0:v]setpts=${VIDEO_PTS}*PTS[v];[0:a]${AUDIO_FILTER}[a]" \
            -map "[v]" -map "[a]" \
            -c:v libx264 -preset medium -crf 23 \
            -c:a aac -b:a 128k \
            "$OUTPUT_FILE" 2>&1
        
        log "Speed change complete"
        ;;

    # ============================================
    # 4 = Change framerate
    # Params: target_fps
    # Example: ffmpeg_runner.sh 4 input.mp4 output.mp4 30
    # ============================================
    4)
        TARGET_FPS="${4:-30}"
        log "Changing framerate to ${TARGET_FPS} fps"
        
        ffmpeg -y -i "$INPUT_FILE" \
            -vf "fps=$TARGET_FPS" \
            -c:v libx264 -preset medium -crf 23 \
            -c:a aac -b:a 128k \
            "$OUTPUT_FILE" 2>&1
        
        log "Framerate change complete"
        ;;

    # ============================================
    # 5 = Extract thumbnail (JPEG)
    # Params: timestamp
    # Example: ffmpeg_runner.sh 5 input.mp4 thumb.jpg 00:00:05
    # ============================================
    5)
        TIMESTAMP="${4:-00:00:01}"
        log "Extracting thumbnail at $TIMESTAMP"
        
        ffmpeg -y -i "$INPUT_FILE" \
            -ss "$TIMESTAMP" \
            -vframes 1 \
            -q:v 2 \
            "$OUTPUT_FILE" 2>&1
        
        log "Thumbnail extraction complete"
        ;;

    # ============================================
    # 6 = Extract audio (MP3)
    # Params: bitrate (optional)
    # Example: ffmpeg_runner.sh 6 input.mp4 output.mp3 192k
    # ============================================
    6)
        BITRATE="${4:-192k}"
        log "Extracting audio at ${BITRATE} bitrate"
        
        ffmpeg -y -i "$INPUT_FILE" \
            -vn \
            -acodec libmp3lame -b:a "$BITRATE" \
            "$OUTPUT_FILE" 2>&1
        
        log "Audio extraction complete"
        ;;

    *)
        error "Unknown operation: $OPERATION"
        echo "Valid operations:"
        echo "  1 = Resize video (params: width height)"
        echo "  2 = Cut/Trim video (params: start_time duration)"
        echo "  3 = Change speed (params: speed_factor)"
        echo "  4 = Change framerate (params: target_fps)"
        echo "  5 = Extract thumbnail (params: timestamp)"
        echo "  6 = Extract audio (params: bitrate)"
        exit 1
        ;;
esac

if [[ -f "$OUTPUT_FILE" ]]; then
    OUTPUT_SIZE=$(stat -c%s "$OUTPUT_FILE" 2>/dev/null || echo "unknown")
    log "Output file created: $OUTPUT_FILE ($OUTPUT_SIZE bytes)"
else
    error "Output file was not created!"
    exit 1
fi

log "Operation $OPERATION completed successfully"