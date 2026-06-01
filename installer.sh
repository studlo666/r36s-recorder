#!/bin/bash

# Define paths
REPO_BASE="https://raw.githubusercontent.com/studlo666/r36s-recorder/main"
TOOLS_DIR="/roms/tools"
ICONS_DIR="/roms/icons"
RECORDER_PATH="$TOOLS_DIR/recorder.sh"

echo "[*] Installing Universal R36S Recorder..."

# 1. Ensure structure
sudo mkdir -p "$TOOLS_DIR" "$ICONS_DIR"

# 2. Sync Assets
FILES=("defaultdpad.png" "up.png" "down.png" "left.png" "right.png" "joystick.png" \
       "defaulta.png" "selecta.png" "defaultb.png" "selectb.png" \
       "defaultx.png" "selectX.png" "defaulty.png" "selecty.png" "defaultfn.png" "selectfn.png")

for file in "${FILES[@]}"; do
    sudo wget -q "$REPO_BASE/$file" -O "$ICONS_DIR/$file"
done

# 3. Create the Universal Recorder Engine
cat << 'EOF' | sudo tee "$RECORDER_PATH" > /dev/null
#!/bin/bash
VIDEO_DIR="/roms/videos"
ICONS_DIR="/roms/icons"
SHM_DIR="/dev/shm/recorder_assets"
PID_FILE="/tmp/ffmpeg_recorder.pid"
DOT_PNG="$SHM_DIR/dot.png"

# Generate local red dot (bypasses FFmpeg color parsing errors)
if [ ! -f "$DOT_PNG" ]; then
    ffmpeg -f lavfi -i color=c=red:s=20x20 -frames:v 1 "$DOT_PNG" -y >/dev/null 2>&1
fi

start_recording() {
    [ -f "$PID_FILE" ] && return
    # nohup/setsid detaches process from EmulationStation, ensuring survival
    nohup ffmpeg -y -f fbdev -r 30 -i /dev/fb0 \
      -i "$DOT_PNG" \
      -f alsa -ac 2 -i default \
      -filter_complex "[0:v][1:v]overlay=10:10[outv]" \
      -map "[outv]" -map 2:a -c:v libx264 -preset ultrafast -crf 28 \
      "$VIDEO_DIR/capture_$(date +%Y%m%d_%H%M%S).mp4" >/dev/null 2>&1 &
    echo $! > "$PID_FILE"
}

# Persistent Input Listener
# Trigger: FN (08) + L1 (06) + R1 (07)
hexdump -v -e '1/1 "%02x " "\n"' /dev/input/js0 2>/dev/null | while read -r line; do
    if [[ "$line" == *"01 08 01"* ]]; then
        if [ ! -f "$PID_FILE" ]; then start_recording; else kill $(cat "$PID_FILE"); rm "$PID_FILE"; fi
        sleep 2
    fi
done
EOF

# 4. Finalize
sudo chmod +x "$RECORDER_PATH"
sudo pkill -f "hexdump"
setsid "$RECORDER_PATH" >/dev/null 2>&1 &

echo "[✓] Installation complete. Press FN + L1 + R1 to toggle recording anywhere."
