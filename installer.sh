#!/bin/bash

# --- CONFIGURATION ---
TOOLS_DIR="/roms/tools"
SHM_DIR="/dev/shm/recorder_assets"
VIDEO_DIR="/roms/videos"
RECORDER_PATH="$TOOLS_DIR/recorder.sh"
LOG_FILE="$VIDEO_DIR/log.txt"
FFMPEG="/usr/bin/ffmpeg"

echo "[*] Installing Pro-Grade Toggle Recorder..."

# 1. Setup Directories & Permissions
sudo mkdir -p "$TOOLS_DIR" "$SHM_DIR" "$VIDEO_DIR"
sudo touch "$LOG_FILE"
sudo chmod 666 "$LOG_FILE"

# 2. Generate Red Dot Asset
sudo $FFMPEG -f lavfi -i color=c=red:s=20x20 -frames:v 1 "$SHM_DIR/dot.png" -y >/dev/null 2>&1

# 3. Create the Smart Recorder Script (Split-Stream Logic)
cat << 'EOF' | sudo tee "$RECORDER_PATH" > /dev/null
#!/bin/bash
PID_FILE="/tmp/ffmpeg_recorder.pid"
LOG_FILE="/roms/videos/log.txt"
DOT="/dev/shm/recorder_assets/dot.png"
FFMPEG="/usr/bin/ffmpeg"

toggle() {
    if [ ! -f "$PID_FILE" ]; then
        # --- START: Split Stream (Dot on Screen / Clean to File) ---
        # 1. Take raw input from /dev/fb0
        # 2. Overlay dot and send to screen
        # 3. Save clean copy to file
        nohup $FFMPEG -y -f fbdev -r 30 -i /dev/fb0 \
          -i "$DOT" \
          -filter_complex "[0:v][1:v]overlay=10:10:format=auto[dot];[dot]split[scr][vid];[scr]format=bgra[scr_out]" \
          -map "[scr_out]" -f fbdev /dev/fb0 \
          -map "[vid]" -c:v libx264 -preset ultrafast -crf 28 \
          "/roms/videos/capture_$(date +%Y%m%d_%H%M%S).mp4" >> "$LOG_FILE" 2>&1 &
        
        echo $! > "$PID_FILE"
        echo "[$(date)] Recording Started." >> "$LOG_FILE"
    else
        kill $(cat "$PID_FILE")
        rm "$PID_FILE"
        echo "[$(date)] Recording Stopped." >> "$LOG_FILE"
    fi
}

# Controller Listener (FN+Start = 01 08 01)
if [ "$1" == "toggle" ]; then
    toggle
else
    hexdump -v -e '1/1 "%02x " "\n"' /dev/input/js0 2>/dev/null | while read -r line; do
        if [[ "$line" == *"01 08 01"* ]]; then
            $0 toggle
            sleep 2
        fi
    done
fi
EOF

# 4. Finalize
sudo chmod +x "$RECORDER_PATH"
# Run the listener as a background process
setsid "$RECORDER_PATH" >/dev/null 2>&1 &
echo "[✓] Installation complete! Recording toggles with FN+Start."
