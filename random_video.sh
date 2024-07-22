#!/bin/bash

# Directory containing video files
VIDEO_DIR="./videos"

# Duration of the random segment in seconds
SEGMENT_DURATION=5

# Temporary directories for short video clips and playlist file
TEMP_DIR="./temp_clips"
PLAYLIST_FILE="./temp_playlist.m3u"
DEBUG_PLAYLIST_FILE="./debug_playlist.txt"  # File to save playlist for debugging

# Create directories for temporary clips and saved clips if they don't exist
mkdir -p "$TEMP_DIR"

# Function to generate and play random 5-second segments from videos
play_random_segments() {
  # List all video files in the directory
  VIDEO_FILES=("$VIDEO_DIR"/*)

  # Check if there are video files in the directory
  if [ ${#VIDEO_FILES[@]} -eq 0 ]; then
    echo "No video files found in the directory."
    exit 1
  fi

  # Generate the playlist
  > "$PLAYLIST_FILE" # Empty the playlist file

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
      START_TIME=$((RANDOM % (VIDEO_DURATION - SEGMENT_DURATION)))
      echo "Start time: $START_TIME seconds"

      # Generate a temporary clip file with absolute path
      CLIP_NAME="$TEMP_DIR/clip_$(date +%s).mp4"
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

      # Add the clip to the playlist file with full path
      ABSOLUTE_CLIP_PATH=$(readlink -f "$CLIP_NAME")
      echo "$ABSOLUTE_CLIP_PATH" >> "$PLAYLIST_FILE"
      echo "Added to playlist: $ABSOLUTE_CLIP_PATH"

      # Log the playlist file being played
      echo "Playing playlist: $PLAYLIST_FILE"
      echo "Contents of playlist file:"
      echo "$PLAYLIST_FILE"

      # Play the playlist using mpv
      mpv --loop-playlist "$PLAYLIST_FILE" || {
        echo "Error playing playlist with mpv. Check if the format is compatible."
        exit 1
      }

      # Clean up the temporary clip file
      rm "$CLIP_NAME"

      # Clear the playlist file
      > "$PLAYLIST_FILE"
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
    echo "Removing temporary playlist file: $PLAYLIST_FILE"
    rm "$PLAYLIST_FILE"
  fi
  exit 0
}

# Trap SIGINT (Ctrl+C) and call cleanup function
trap cleanup SIGINT

# Start playing random segments
play_random_segments
