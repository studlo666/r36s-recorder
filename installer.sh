#!/bin/bash

# Configuration
REPO_BASE="https://raw.githubusercontent.com/studlo666/r36s-recorder/main"
TOOLS_DIR="/roms/tools"
ICONS_DIR="/roms/icons"
SHM_DIR="/dev/shm/recorder_assets"
RECORDER_PATH="$TOOLS_DIR/recorder.sh"

echo "[*] Initializing environment..."
sudo mkdir -p "$TOOLS_DIR" "$ICONS_DIR" "$SHM_DIR"

# 1. Sync required assets
FILES=("defaultdpad.png" "up.png" "down.png" "left.png" "right.png" "joystick.png" \
       "defaulta.png" "selecta.png" "defaultb.png" "selectb.png" \
       "defaultx.png" "selectX.png" "defaulty.png" "selecty.png" "defaultfn.png" "selectfn.png")

for file in "${FILES[@]}"; do
    sudo wget -q "$REPO_BASE/$file" -O "$ICONS_DIR/$file"
    # Copy to SHM so FFmpeg can find them
    sudo cp "$ICONS_DIR/$file" "$SHM_DIR/$file"
done

# Create a local red dot for the indicator
sudo ffmpeg -f lavfi -i color=c=red:s=20x20 -frames:v 1 "$SHM_DIR/dot.png" -y >/dev/null 2>&1

# 2. Universal Recorder Script
cat << 'EOF' | sudo tee "$RECORDER_PATH" > /dev/null
#!/bin/bash
VIDEO_DIR="/roms/videos"
SHM_DIR="/dev/shm/recorder_assets"
PID_FILE="/tmp/ffmpeg_recorder.pid"

start_recording() {
    [ -f "$PID_FILE" ] && return
    # Recording command with overlay of dot.png
    nohup ffmpeg -y -f fbdev -r 30 -i /dev/fb0 \
      -i "$SHM_DIR/dot.png" \
      -f alsa -ac 2 -i default \
      -filter_complex "[0:v][1:v]overlay=10:10[outv]" \
      -map "[outv]" -map 2:a -c:v libx264 -preset ultrafast -crf 28 \
      "$VIDEO_DIR/capture_$(date +%Y%m%d_%H%M%S).mp4" >/dev/null 2>&1 &
    echo $! > "$PID_FILE"
}

# Persistent Input Listener
hexdump -v -e '1/1 "%02x " "\n"' /dev/input/js0 2>/dev/null | while read -r line; do
    if [[ "$line" == *"01 08 01"* ]]; then
        if [ ! -f "$PID_FILE" ]; then start_recording; else kill $(cat "$PID_FILE"); rm "$PID_FILE"; fi
        sleep 2
    fi
done
EOF

# 3. Finalize
sudo chmod +x "$RECORDER_PATH"
sudo pkill -f "hexdump"
setsid "$RECORDER_PATH" >/dev/null 2>&1 &
echo "[✓] Environment initialized. All assets copied to SHM."
