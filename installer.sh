#!/bin/bash

VIDEO_DIR="/roms/videos"
ICONS_DIR="/roms/icons"
SHM_DIR="/dev/shm/recorder_assets"
PID_FILE="/tmp/ffmpeg_recorder.pid"
INPUT_PID_FILE="/tmp/input_listener.pid"
DEBUG_LOG="/roms/videos/log.txt"

echo "=== GITHUB MATCHED RECORDER ACTIVE: $(date) ===" > "$DEBUG_LOG"

if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    INPUT_PID=$(cat "$INPUT_PID_FILE" 2>/dev/null)
    if ps -p $PID > /dev/null 2>&1; then
        sudo kill -2 "$PID"
        [ ! -z "$INPUT_PID" ] && sudo kill "$INPUT_PID"
        sudo rm "$PID_FILE" "$INPUT_PID_FILE" 2>/dev/null
        echo "[SUCCESS] Recorder closed safely and video finalized." >> "$DEBUG_LOG"
        exit 0
    else
        sudo rm "$PID_FILE" "$INPUT_PID_FILE" 2>/dev/null
    fi
fi

# Prime active baseline frames
cp "$ICONS_DIR/defaultdpad.png" "$SHM_DIR/dpad.png" 2>/dev/null
cp "$ICONS_DIR/defaulta.png" "$SHM_DIR/btn_a.png" 2>/dev/null
echo "0" > "$SHM_DIR/joy_x"
echo "0" > "$SHM_DIR/joy_y"

# 3. Dynamic Subsystem Input Monitoring Engine
hexdump -v -e '1/1 "%02x " "\n"' /dev/input/js0 2>/dev/null | while read -r line; do
    if [[ "$line" == *"02"* ]]; then
        if [[ "$line" == *"00 01"* || "$line" == *"00 80"* ]]; then
            echo "-20" > "$SHM_DIR/joy_x"
        elif [[ "$line" == *"00 7f"* ]]; then
            echo "20" > "$SHM_DIR/joy_x"
        elif [[ "$line" == *"01 01"* || "$line" == *"01 80"* ]]; then
            echo "-20" > "$SHM_DIR/joy_y"
        elif [[ "$line" == *"01 7f"* ]]; then
            echo "20" > "$SHM_DIR/joy_y"
        fi
    elif [[ "$line" == *"01"* ]]; then
        if [[ "$line" == *"01 80 01"* || "$line" == *"02 80 01"* ]]; then
            cp "$ICONS_DIR/up.png" "$SHM_DIR/dpad.png" 2>/dev/null
        elif [[ "$line" == *"01 7f 01"* || "$line" == *"02 7f 01"* ]]; then
            cp "$ICONS_DIR/down.png" "$SHM_DIR/dpad.png" 2>/dev/null
        elif [[ "$line" == *"01 04 01"* || "$line" == *"02 04 01"* ]]; then
            cp "$ICONS_DIR/left.png" "$SHM_DIR/dpad.png" 2>/dev/null
        elif [[ "$line" == *"01 05 01"* || "$line" == *"02 05 01"* ]]; then
            cp "$ICONS_DIR/right.png" "$SHM_DIR/dpad.png" 2>/dev/null
        elif [[ "$line" == *"01 01 01"* ]]; then
            cp "$ICONS_DIR/selecta.png" "$SHM_DIR/btn_a.png" 2>/dev/null
        fi
    elif [[ "$line" == *"00 00"* ]]; then
        echo "0" > "$SHM_DIR/joy_x"
        echo "0" > "$SHM_DIR/joy_y"
        cp "$ICONS_DIR/defaultdpad.png" "$SHM_DIR/dpad.png" 2>/dev/null
        cp "$ICONS_DIR/defaulta.png" "$SHM_DIR/btn_a.png" 2>/dev/null
    fi
done &
echo $! | sudo tee "$INPUT_PID_FILE" > /dev/null

RANDOM_HASH=$(head /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 5)
OUTPUT_FILE="${VIDEO_DIR}/r36s_capture_$(date +%Y%m%d_%H%M%S).mp4"

# 4. Master Composite FFmpeg Engine (Corrected)
sudo ffmpeg -y \
  -f fbdev -r 30 -i /dev/fb0 \
  -loop 1 -i "$SHM_DIR/dpad.png" \
  -loop 1 -i "$SHM_DIR/btn_a.png" \
  -loop 1 -i "$ICONS_DIR/joystick.png" \
  -f alsa -ac 2 -i default \
  -filter_complex \
  "color=c=black:s=640x940[bg]; \
   [0:v]scale=640:480[game]; \
   [bg][game]overlay=0:0[canvas1]; \
   [canvas1][1:v]overlay=40:560:shortest=1[canvas2]; \
   [canvas2][2:v]overlay=440:560:shortest=1[canvas3]; \
   [canvas3][3:v]overlay=140:740:shortest=1[canvas4]; \
   color=c=black@0.0:s=30x30,format=rgba[knob_bg]; \
   geq=r='if(lte(hypot(X-15,Y-15),10),0,0)':g='if(lte(hypot(X-15,Y-15),10),0,0)':b='if(lte(hypot(X-15,Y-15),10),0,0)':a='if(lte(hypot(X-15,Y-15),10),255,0)'[knob_circle]; \
   [knob_bg][knob_circle]alphamerge[knob]; \
   [canvas4][knob]overlay='225+text(file(/dev/shm/recorder_assets/joy_x))':'825+text(file(/dev/shm/recorder_assets/joy_y))':shortest=1[outv]" \
  -map "[outv]" -map 4:a \
  -c:v libx264 -preset ultrafast -crf 28 -pix_fmt yuv420p \
  -c:a aac -b:a 96k \
  "$OUTPUT_FILE" >> "$DEBUG_LOG" 2>&1 &

echo $! | sudo tee "$PID_FILE" > /dev/null
echo "[SUCCESS] Dynamic layout recording initialization successful." >> "$DEBUG_LOG"
