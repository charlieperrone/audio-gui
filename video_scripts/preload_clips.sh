#!/bin/bash

# Directory containing video files
VIDEO_DIR="./videos"

# Duration of the random segment in seconds
SEGMENT_DURATION=20

# Temporary directories for short video clips
TEMP_DIR="./temp_clips"
mkdir -p "$TEMP_DIR"

# Preload and return the path of a new clip
preload_clip() {
# List all video files in the directory
  VIDEO_FILES=("$VIDEO_DIR"/*)
  RANDOM_VIDEO=${VIDEO_FILES[$RANDOM % ${#VIDEO_FILES[@]}]}
  VIDEO_DURATION=$(ffprobe -v error -select_streams v:0 -show_entries stream=duration -of default=noprint_wrappers=1:nokey=1 "$RANDOM_VIDEO")
  VIDEO_DURATION=${VIDEO_DURATION%.*}
  if [ "$VIDEO_DURATION" -ge "$SEGMENT_DURATION" ]; then
    if [ "$VIDEO_DURATION" -gt "$SEGMENT_DURATION" ]; then
      START_TIME=$((RANDOM % (VIDEO_DURATION - SEGMENT_DURATION)))
    else
      START_TIME=0
    fi

    BASENAME=$(basename $RANDOM_VIDEO .mp4)
    MINUTES=$(($START_TIME / 60))
    SECONDS=$(($START_TIME % 60))
    CLIP_NAME="$TEMP_DIR/$BASENAME $MINUTES $SECONDS.mp4"
    ffmpeg -ss "$START_TIME" -t "$SEGMENT_DURATION" -i "$RANDOM_VIDEO" -c:v libx264 -preset veryfast -crf 23 -c:a aac "$CLIP_NAME" -y
    if [ -f "$CLIP_NAME" ]; then
      echo '{ "command": ["loadfile", "'"$CLIP_NAME"'", "replace"] }' | socat - "$MPV_SOCKET"
      LAST_CLIP="$CLIP_NAME"
    fi
  fi
}

preload_clip