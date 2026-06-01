#!/bin/bash

VIDEO_DIR="/roms/videos"
ICONS_DIR="/roms/icons"
SHM_DIR="/dev/shm/recorder_assets"
PID_FILE="/tmp/ffmpeg_recorder.pid"
DOT_PNG="$SHM_DIR/dot.png"

# Generate the red dot file ONCE at start to avoid color parsing errors
if [ ! -f "$DOT_PNG" ]; then
    ffmpeg -f lavfi -i color=c=red:s=20x20 -frames:v 1 "$DOT_PNG" >/dev/null 2>&1
fi

start_recording() {
    # If a recording is already running, exit
    [ -f "$PID_FILE" ] && return
    
    # Detached recorder: uses nohup to ignore termination signals from ES
    # Overlay the pre-generated red dot at 10:10
    nohup ffmpeg -y -f fbdev -r 30 -i /dev/fb0 \
      -i "$DOT_PNG" \
      -f alsa -ac 2 -i default \
      -filter_complex "[0:v][1:v]overlay=10:10[outv]" \
      -map "[outv]" -map 2:a -c:v libx264 -preset ultrafast -crf 28 \
      "$VIDEO_DIR/capture_$(date +%Y%m%d_%H%M%S).mp4" >/dev/null 2>&1 &
    
    echo $! > "$PID_FILE"
}

# Input Listener (Runs permanently in background)
# Toggle: FN (08) + L1 (06) + R1 (07)
hexdump -v -e '1/1 "%02x " "\n"' /dev/input/js0 2>/dev/null | while read -r line; do
    if [[ "$line" == *"01 08 01"* ]]; then
        if [ ! -f "$PID_FILE" ]; then 
            start_recording
        else 
            kill $(cat "$PID_FILE") 2>/dev/null; rm "$PID_FILE" 
        fi
        sleep 2 # Debounce
    fi
done &
