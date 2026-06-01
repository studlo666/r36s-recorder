#!/bin/bash

# Configuration
REPO_BASE="https://raw.githubusercontent.com/studlo666/r36s-recorder/main"
TOOLS_DIR="/roms/tools"
ICONS_DIR="/roms/icons"
SHM_DIR="/dev/shm/recorder_assets"
VIDEO_DIR="/roms/videos"
RECORDER_PATH="$TOOLS_DIR/recorder.sh"
LOG_FILE="$VIDEO_DIR/log.txt"
FFMPEG="/usr/bin/ffmpeg"

echo "[*] Installing Recorder Toggle System..."

# 1. Setup Directories
sudo mkdir -p "$TOOLS_DIR" "$ICONS_DIR" "$SHM_DIR" "$VIDEO_DIR"
sudo touch "$LOG_FILE"
sudo chmod 666 "$LOG_FILE"

# 2. Sync Assets
FILES=("defaultdpad.png" "up.png" "down.png" "right.png" "joystick.png" \
       "defaulta.png" "selecta.png" "defaultb.png" "selectb.png" \
       "defaultx.png" "selectX.png" "defaulty.png" "selecty.png" "defaultfn.png" "selectfn.png")

for file in "${FILES[@]}"; do
    sudo wget -q "$REPO_BASE/$file" -O "$ICONS_DIR/$file"
    sudo cp "$ICONS_DIR/$file" "$SHM_DIR/$file"
done
sudo ffmpeg -f lavfi -i color=c=red:s=20x20 -frames:v 1 "$SHM_DIR/dot.png" -y >/dev/null 2>&1

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
    nohup $FFMPEG -y -f fbdev -r 30 -i /dev/fb0 \
      -i "$SHM_DIR/dot.png" \
      -f alsa -ac 2 -i default \
      -filter_complex "[0:v][1:v]overlay=10:10[outv]" \
      -map "[outv]" -map 2:a -c:v libx264 -preset ultrafast -crf 28 \
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
echo "[✓] Installation complete. Run '/roms/tools/recorder.sh' to toggle recording."
