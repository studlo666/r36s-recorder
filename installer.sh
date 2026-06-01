#!/bin/bash

# Configuration
REPO_BASE="https://raw.githubusercontent.com/studlo666/r36s-recorder/main"
TOOLS_DIR="/roms/tools"
ICONS_DIR="/roms/icons"
RECORDER_PATH="$TOOLS_DIR/recorder.sh"

echo "[*] Initializing live installation..."

# Create necessary directories
sudo mkdir -p "$TOOLS_DIR" "$ICONS_DIR"

# Fetch required icons directly from your repository
FILES=("defaultdpad.png" "up.png" "down.png" "left.png" "right.png" "joystick.png" \
       "defaulta.png" "selecta.png" "defaultb.png" "selectb.png" \
       "defaultx.png" "selectX.png" "defaulty.png" "selecty.png" "defaultfn.png" "selectfn.png")

for file in "${FILES[@]}"; do
    echo "[*] Syncing $file..."
    sudo wget -q "$REPO_BASE/$file" -O "$ICONS_DIR/$file"
done

# Create the universal recorder script
cat << 'EOF' | sudo tee "$RECORDER_PATH" > /dev/null
#!/bin/bash

VIDEO_DIR="/roms/videos"
ICONS_DIR="/roms/icons"
SHM_DIR="/dev/shm/recorder_assets"
PID_FILE="/tmp/ffmpeg_recorder.pid"
DEBUG_LOG="/roms/videos/log.txt"
DOT_PNG="$SHM_DIR/dot.png"

# Setup transparency
mkdir -p "$SHM_DIR"
ffmpeg -f lavfi -i color=c=red:s=20x20 -frames:v 1 "$DOT_PNG" -y >/dev/null 2>&1

start_recording() {
    [ -f "$PID_FILE" ] && kill $(cat "$PID_FILE") 2>/dev/null
    
    # Detached universal recorder
    nohup ffmpeg -y -f fbdev -r 30 -i /dev/fb0 \
      -i "$DOT_PNG" \
      -f alsa -ac 2 -i default \
      -filter_complex "[0:v][1:v]overlay=10:10[outv]" \
      -map "[outv]" -map 2:a -c:v libx264 -preset ultrafast -crf 28 \
      "$VIDEO_DIR/capture_$(date +%Y%m%d_%H%M%S).mp4" >/dev/null 2>&1 &
    
    echo $! > "$PID_FILE"
}

# Input Listener (Runs permanently)
hexdump -v -e '1/1 "%02x " "\n"' /dev/input/js0 2>/dev/null | while read -r line; do
    # Trigger: FN (08) + L1 (06) + R1 (07)
    if [[ "$line" == *"01 08 01"* ]]; then
        if [ ! -f "$PID_FILE" ]; then start_recording; else kill $(cat "$PID_FILE"); rm "$PID_FILE"; fi
        sleep 2
    fi
done
EOF

# Make executable and start background monitoring
sudo chmod +x "$RECORDER_PATH"
sudo pkill -f "hexdump" # Stop old listener
setsid "$RECORDER_PATH" >/dev/null 2>&1 &

echo "[✓] Installation complete. Recorder is live."
