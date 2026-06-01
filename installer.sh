#!/bin/bash

# --- CONFIGURATION ---
TOOLS_DIR="/roms/tools"
ICONS="/roms/icons"
VIDEO_DIR="/roms/videos"
LOG_FILE="$VIDEO_DIR/log.txt"
RECORDER_PATH="$TOOLS_DIR/recorder.sh"
FFMPEG="/usr/bin/ffmpeg"

echo "[*] Installing Pro-Grade R36S Video Recorder..."

# 1. Setup Environment
sudo mkdir -p "$TOOLS_DIR" "$ICONS" "$VIDEO_DIR"
sudo touch "$LOG_FILE"
sudo chmod 666 "$LOG_FILE"

# 2. Create the Stable Recorder Script
cat << 'EOF' | sudo tee "$RECORDER_PATH" > /dev/null
#!/bin/bash
PID_FILE="/tmp/ffmpeg_recorder.pid"
LOG_FILE="/roms/videos/log.txt"
ICONS="/roms/icons"
# Initial State variables
A_S=0; B_S=0; X_S=0; Y_S=0; FN_S=0

toggle() {
    if [ ! -f "$PID_FILE" ]; then
        # Video-only capture, 640x940 canvas
        # Audio removed to eliminate hang issues
        nohup $FFMPEG -y -f fbdev -r 30 -i /dev/fb0 \
          -i "$ICONS/defaulta.png" -i "$ICONS/selecta.png" \
          -i "$ICONS/defaultb.png" -i "$ICONS/selectb.png" \
          -i "$ICONS/defaultx.png" -i "$ICONS/selectx.png" \
          -i "$ICONS/defaulty.png" -i "$ICONS/selecty.png" \
          -i "$ICONS/defaultfn.png" -i "$ICONS/selectfn.png" \
          -filter_complex "[0:v]pad=640:940:0:0:black[base]; \
          [base][2:v]overlay=500:600:enable='eq(A_S,0)'[v1]; [v1][3:v]overlay=500:600:enable='eq(A_S,1)'[v2]; \
          [v2][4:v]overlay=500:670:enable='eq(B_S,0)'[v3]; [v3][5:v]overlay=500:670:enable='eq(B_S,1)'[v4]; \
          [v4][6:v]overlay=430:600:enable='eq(X_S,0)'[v5]; [v5][7:v]overlay=430:600:enable='eq(X_S,1)'[v6]; \
          [v6][8:v]overlay=430:670:enable='eq(Y_S,0)'[v7]; [v7][9:v]overlay=430:670:enable='eq(Y_S,1)'[v8]; \
          [v8][10:v]overlay=250:750:enable='eq(FN_S,0)'[v9]; [v9][11:v]overlay=250:750:enable='eq(FN_S,1)'[outv]" \
          -map "[outv]" -c:v libx264 -preset ultrafast -crf 28 \
          "/roms/videos/capture_$(date +%Y%m%d_%H%M%S).mp4" >> "$LOG_FILE" 2>&1 &
        echo $! > "$PID_FILE"
    else
        kill $(cat "$PID_FILE")
        rm "$PID_FILE"
    fi
}

# Controller Listener
hexdump -v -e '1/1 "%02x " "\n"' /dev/input/js0 2>/dev/null | while read -r line; do
    [[ "$line" == *"01 08 01"* ]] && toggle
done
EOF

# 3. Finalize
sudo chmod +x "$RECORDER_PATH"
# Run the listener
setsid "$RECORDER_PATH" >/dev/null 2>&1 &
echo "[✓] Installation complete."
