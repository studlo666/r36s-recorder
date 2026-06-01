#!/bin/bash

# Configuration
REPO_BASE="https://raw.githubusercontent.com/studlo666/r36s-recorder/main"
TOOLS_DIR="/roms/tools"
ICONS_DIR="/roms/icons"
SHM_DIR="/dev/shm/recorder_assets"
RECORDER_PATH="$TOOLS_DIR/recorder.sh"

echo "[*] Creating environment..."
sudo mkdir -p "$TOOLS_DIR" "$ICONS_DIR" "$SHM_DIR"

# Ensure dummy image exists to stop FFmpeg crashes
sudo ffmpeg -f lavfi -i color=c=red:s=20x20 -frames:v 1 "$SHM_DIR/dot.png" -y >/dev/null 2>&1

# Create the persistent recorder
cat << 'EOF' | sudo tee "$RECORDER_PATH" > /dev/null
#!/bin/bash
VIDEO_DIR="/roms/videos"
SHM_DIR="/dev/shm/recorder_assets"
PID_FILE="/tmp/ffmpeg_recorder.pid"

start_recording() {
    [ -f "$PID_FILE" ] && return
    
    # Simple recording command to test functionality
    nohup ffmpeg -y -f fbdev -r 30 -i /dev/fb0 \
      -f alsa -ac 2 -i default \
      -c:v libx264 -preset ultrafast -crf 28 \
      "$VIDEO_DIR/capture_$(date +%Y%m%d_%H%M%S).mp4" >/dev/null 2>&1 &
    
    echo $! > "$PID_FILE"
}

# Input Listener
hexdump -v -e '1/1 "%02x " "\n"' /dev/input/js0 2>/dev/null | while read -r line; do
    if [[ "$line" == *"01 08 01"* ]]; then
        if [ ! -f "$PID_FILE" ]; then start_recording; else kill $(cat "$PID_FILE"); rm "$PID_FILE"; fi
        sleep 2
    fi
done
EOF

sudo chmod +x "$RECORDER_PATH"
sudo pkill -f "hexdump"
setsid "$RECORDER_PATH" >/dev/null 2>&1 &
echo "[✓] Installation complete."
