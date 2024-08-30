#!/bin/bash

# Directory containing video files
VIDEO_DIR="./videos/tc-vids"

# Directory to save the video segments
SEGMENTS_DIR="./video_segments"
mkdir -p "$SEGMENTS_DIR"

# Duration of the random segment in seconds
SEGMENT_DURATION=60

# Function to generate a unique name for the clip based on the original filename and start time
generate_clip_name() {
  local original_filename=$(basename "$1")
  local start_time=$2
  local minutes=$(printf "%02d" $((start_time / 60)))
  local seconds=$(printf "%02d" $((start_time % 60)))
  echo "$SEGMENTS_DIR/${original_filename%.mp4}_${minutes}:${seconds}.mp4"
}

# Function to create random 5-second segments from videos
create_random_segments() {
  # List all video files in the directory
  VIDEO_FILES=("$VIDEO_DIR"/*)

  # Check if there are video files in the directory
  if [ ${#VIDEO_FILES[@]} -eq 0 ]; then
    echo "No video files found in the directory."
    exit 1
  fi

  while true; do
    # Randomly select a video file from the list
    RANDOM_VIDEO=${VIDEO_FILES[$RANDOM % ${#VIDEO_FILES[@]}]}
    echo "Selected video: $RANDOM_VIDEO"

    # Get the duration of the selected video file
    VIDEO_DURATION=$(ffprobe -v error -select_streams v:0 -show_entries stream=duration -of default=noprint_wrappers=1:nokey=1 "$RANDOM_VIDEO")
    VIDEO_DURATION=${VIDEO_DURATION%.*}
    echo "Video duration: $VIDEO_DURATION seconds"

    # Check if the video is longer than the segment duration
    if [ "$VIDEO_DURATION" -ge "$SEGMENT_DURATION" ]; then
      # Calculate a random start time for the segment
      if [ "$VIDEO_DURATION" -gt "$SEGMENT_DURATION" ]; then
        START_TIME=$((RANDOM % (VIDEO_DURATION - SEGMENT_DURATION)))
      else
        START_TIME=0
      fi
      echo "Start time: $START_TIME seconds"

      # Generate a unique clip file name with absolute path
      CLIP_NAME=$(generate_clip_name "$RANDOM_VIDEO" "$START_TIME")
      echo "Creating clip: $CLIP_NAME from $RANDOM_VIDEO (Start: $START_TIME, Duration: $SEGMENT_DURATION)"

      # Extract the 5-second segment using ffmpeg
      ffmpeg -ss "$START_TIME" -t "$SEGMENT_DURATION" -i "$RANDOM_VIDEO" -c:v libx264 -preset veryfast -crf 23 -c:a aac "$CLIP_NAME" -y

      # Check if the clip file was created successfully
      if [ ! -f "$CLIP_NAME" ]; then
        echo "Failed to create clip: $CLIP_NAME"
        continue
      fi

      # Optional: Break after creating a certain number of clips or based on user-defined condition
      # For example, break after creating 10 clips
      # if [ $(ls -1q "$SEGMENTS_DIR" | wc -l) -ge 10 ]; then
      #   break
      # fi

      # Wait a short time before processing the next clip
      sleep 1
    else
      echo "Video $RANDOM_VIDEO is too short for the segment duration."
    fi
  done
}


# Function to handle cleanup on script exit
cleanup() {
  echo "Exiting..."
  exit 0
}

# Trap SIGINT (Ctrl+C) and call cleanup function
trap cleanup SIGINT

# Start creating random segments
create_random_segments
