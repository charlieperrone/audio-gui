#!/bin/bash

# Directory containing video files
VIDEO_DIR="./videos"

# Directory to save the video segments
SEGMENTS_DIR="./video_segments"
mkdir -p "$SEGMENTS_DIR"

# Duration of the random segment in seconds
SEGMENT_DURATION=5

# Temporary directories for short video clips
TEMP_DIR="./temp_clips"
mkdir -p "$TEMP_DIR"

# IPC socket file for mpv
MPV_SOCKET="/tmp/mpvsocket"

# Set the desired window dimensions
WINDOW_WIDTH=800
WINDOW_HEIGHT=600

# Variable to keep track of the last clip
LAST_CLIP=""

# Function to generate a unique name for the clip based on original filename and start time
generate_clip_name() {
  local original_filename=$(basename "$1")
  local start_time=$2
  local minutes=$(printf "%02d" $((start_time / 60)))
  local seconds=$(printf "%02d" $((start_time % 60)))
  echo "$SEGMENTS_DIR/${original_filename%.mp4}_${minutes}${seconds}.mp4"
}

# Preload and return the path of a new clip
preload_clip() {
  RANDOM_VIDEO=${VIDEO_FILES[$RANDOM % ${#VIDEO_FILES[@]}]}
  VIDEO_DURATION=$(ffprobe -v error -select_streams v:0 -show_entries stream=duration -of default=noprint_wrappers=1:nokey=1 "$RANDOM_VIDEO")
  VIDEO_DURATION=${VIDEO_DURATION%.*}
  if [ "$VIDEO_DURATION" -ge "$SEGMENT_DURATION" ]; then
    if [ "$VIDEO_DURATION" -gt "$SEGMENT_DURATION" ]; then
      START_TIME=$((RANDOM % (VIDEO_DURATION - SEGMENT_DURATION)))
    else
      START_TIME=0
    fi
    CLIP_NAME=$(generate_clip_name "$RANDOM_VIDEO" "$START_TIME")
    ffmpeg -ss "$START_TIME" -t "$SEGMENT_DURATION" -i "$RANDOM_VIDEO" -c:v libx264 -preset veryfast -crf 23 -c:a aac "$CLIP_NAME" -y
    if [ -f "$CLIP_NAME" ]; then
      echo '{ "command": ["loadfile", "'"$CLIP_NAME"'", "replace"] }' | socat - "$MPV_SOCKET"
      LAST_CLIP="$CLIP_NAME"
    fi
  fi
}

# Function to play random 5-second segments from videos
play_random_segments() {
  # List all video files in the directory
  VIDEO_FILES=("$VIDEO_DIR"/*)

  # Check if there are video files in the directory
  if [ ${#VIDEO_FILES[@]} -eq 0 ]; then
    echo "No video files found in the directory."
    exit 1
  fi

  # Preload the first clip to avoid an initial gap
  preload_clip

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

      # Check if the temporary clip file was created successfully
      if [ ! -f "$CLIP_NAME" ]; then
        echo "Failed to create temporary clip: $CLIP_NAME"
        continue
      fi

      # Validate the temporary clip file format
      if ! ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$CLIP_NAME" >/dev/null 2>&1; then
        echo "Invalid file format or encoding: $CLIP_NAME"
        rm "$CLIP_NAME"
        continue
      fi

      # Send command to mpv to append and play the new clip
      echo '{ "command": ["loadfile", "'"$CLIP_NAME"'", "append-play"] }' | socat - "$MPV_SOCKET"

      # Update the last clip variable
      LAST_CLIP="$CLIP_NAME"

      # Wait for the segment duration before processing the next clip
      sleep "$SEGMENT_DURATION"
    else
      echo "Video $RANDOM_VIDEO is too short for the segment duration."
    fi
  done
}

# Function to handle cleanup on script exit
cleanup() {
  echo "Exiting..."
  if [ -d "$TEMP_DIR" ]; then
    echo "Removing temporary clips directory: $TEMP_DIR"
    rm -rf "$TEMP_DIR"
  fi
  # Remove the last clip if it exists
  if [ -n "$LAST_CLIP" ] && [ -f "$LAST_CLIP" ]; then
    echo "Removing last clip: $LAST_CLIP"
    rm "$LAST_CLIP"
  fi
  exit 0
}

# Trap SIGINT (Ctrl+C) and call cleanup function
trap cleanup SIGINT

# Start mpv in idle mode with IPC server and set the window size
mpv --idle --input-ipc-server="$MPV_SOCKET" --geometry="${WINDOW_WIDTH}x${WINDOW_HEIGHT}" --autofit=${WINDOW_WIDTH}x${WINDOW_HEIGHT} &

# Give mpv some time to start up
sleep 1

# Start playing random segments
play_random_segments
