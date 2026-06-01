#!/bin/bash

# --- CONFIGURATION ---
TOOLS_DIR="/roms/tools"
SHM_DIR="/dev/shm/recorder_assets"
VIDEO_DIR="/roms/videos"
RECORDER_PATH="$TOOLS_DIR/recorder.sh"
LOG_FILE="$VIDEO_DIR/log.txt"
FFMPEG="/usr/bin/ffmpeg"

echo "[*] Setting up R36S Screen Recorder..."

# 1. Setup Directories
sudo mkdir -p "$TOOLS_DIR" "$SHM_DIR" "$VIDEO_DIR"
sudo touch "$LOG_FILE"
sudo chmod 666 "$LOG_FILE"

# 2. Generate Red Dot Overlay
sudo $FFMPEG -f lavfi -i color=c=red:s=20x20 -frames:v 1 "$SHM_DIR/dot.png" -y >/dev/null 2>&1

# 3. Create the Toggle Recorder Script
cat << 'EOF' | sudo tee "$RECORDER_PATH" > /dev/null
#!/bin/bash
VIDEO_DIR="/roms/videos"
SHM_DIR="/dev/shm/recorder_assets"
PID_FILE="/tmp/ffmpeg_recorder.pid"
LOG_FILE="$VIDEO_DIR/log.txt"
FFMPEG="/usr/bin/ffmpeg"

if [ ! -f "$PID_FILE" ]; then
    # --- START ---
    # Video only to ensure stability across all R36S builds
    nohup $FFMPEG -y -f fbdev -r 30 -i /dev/fb0 \
      -loop 1 -i "$SHM_DIR/dot.png" \
      -filter_complex "[0:v][1:v]overlay=10:10:format=auto[outv]" \
      -map "[outv]" -c:v libx264 -preset ultrafast -crf 28 \
      "$VIDEO_DIR/capture_$(date +%Y%m%d_%H%M%S).mp4" >> "$LOG_FILE" 2>&1 &
    
    echo $! > "$PID_FILE"
    echo "[$(date)] Started recording." >> "$LOG_FILE"
else
    # --- STOP ---
    kill $(cat "$PID_FILE")
    rm "$PID_FILE"
    echo "[$(date)] Stopped recording." >> "$LOG_FILE"
fi
EOF

# 4. Finalize
sudo chmod +x "$RECORDER_PATH"
echo "[✓] Setup complete!"
echo "[✓] Recording toggles with: /roms/tools/recorder.sh"
