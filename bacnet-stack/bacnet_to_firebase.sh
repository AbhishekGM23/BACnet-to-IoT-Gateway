#!/bin/bash
# bacnet_to_firebase.sh
# Combined: run bacepics -> extract object-name/present-value -> upload to Firebase
# Requirements:
#   - Run from bacnet-stack root (so ./bin/bacepics exists)
#   - jq installed: sudo apt install jq -y
#   - Replace FIREBASE_DB_URL with your DB URL
#   - Ensure RS485 adapter is at BACNET_IFACE device (/dev/ttyACM0)
#
# Exports: This script exports BACNET_* env vars required by the bacnet tools.

#################### CONFIGURATION ####################
FIREBASE_DB_URL="https://backnet-fd8ee-default-rtdb.firebaseio.com/"   # <-- Replace this
DEVICE_ID="1234"                                           # Device ID from your demo server
BACNET_INTERFACE="/dev/ttyACM0"                            # Your RS485 adapter
BACNET_MSTP_BAUD="38400"                                   # Baud rate (match both ends)
BACNET_MSTP_MAC="2"                                        # This node's MS/TP MAC (client)
BACNET_MAX_MASTER="127"                                    # MS/TP max master
BACNET_MAX_INFO_FRAMES="10"                                # MS/TP max info frames
#########################################################

# sanity checks
command -v jq >/dev/null 2>&1 || { echo "❌ 'jq' not found. Install with: sudo apt install jq -y"; exit 1; }
if [ ! -x "./bin/bacepics" ]; then
  echo "❌ ./bin/bacepics not found or not executable. Run this from the bacnet-stack root directory."
  exit 1
fi

# Export BACnet environment variables so bacepics uses MS/TP properly
export BACNET_IFACE="$BACNET_INTERFACE"
export BACNET_MSTP_BAUD="$BACNET_MSTP_BAUD"
export BACNET_MSTP_MAC="$BACNET_MSTP_MAC"
export BACNET_MAX_MASTER="$BACNET_MAX_MASTER"
export BACNET_MAX_INFO_FRAMES="$BACNET_MAX_INFO_FRAMES"

echo "📡 Using BACNET_IFACE=$BACNET_IFACE, BAUD=$BACNET_MSTP_BAUD, MAC=$BACNET_MSTP_MAC"

# Temporary files
RAW_OUTPUT="output.txt"
VALUES_FILE="values.txt"

echo "📡 Reading BACnet data from device ID $DEVICE_ID ..."
# run bacepics with the exported env vars
./bin/bacepics -v "$DEVICE_ID" > "$RAW_OUTPUT" 2>&1
if [ $? -ne 0 ]; then
  echo "❌ bacepics returned a non-zero exit. Show last 40 lines of $RAW_OUTPUT for debugging:"
  tail -n 40 "$RAW_OUTPUT"
  exit 1
fi

echo "✅ BACnet data collected → $RAW_OUTPUT"
echo "🔍 Extracting object-name and present-value pairs..."

# Extract object-name and present-value pairs using awk
awk '
/object-name:/ {
    name=$0
    sub(/.*object-name:[[:space:]]*"/, "", name)
    sub(/".*/, "", name)
}
/present-value:/ {
    val=$0
    sub(/.*present-value:[[:space:]]*/, "", val)
    gsub(/[[:space:]]+Writable$/, "", val)
    sub(/^[[:space:]]+/, "", val)
    sub(/[[:space:]]+$/, "", val)
    if (name != "" && val != "") print name ":" val
    name=""; val=""
}' "$RAW_OUTPUT" > "$VALUES_FILE"

echo "✅ Extracted values → $VALUES_FILE"

# Upload each pair to Firebase
echo "🚀 Uploading values to Firebase Realtime Database..."
while IFS= read -r line; do
  # skip empty lines
  [ -z "$line" ] && continue

  name="${line%%:*}"
  rest="${line#*:}"
  # remove trailing 'Writable' etc (double-check)
  value="$(echo "$rest" | sed -E 's/[[:space:]]+Writable$//; s/^[[:space:]]+//; s/[[:space:]]+$//')"

  # create firebase-safe key
  key="$(echo "$name" | sed -E 's/[^A-Za-z0-9]+/_/g')"

  ts="$(date --iso-8601=seconds)"
  json="$(jq -n --arg v "$value" --arg t "$ts" '{value:$v, timestamp:$t}')"

  # Upload using Firebase REST API (PUT to set exact value). Change to PATCH if you prefer merging.
  response=$(curl -s -o /dev/null -w "%{http_code}" -X PUT \
    "${FIREBASE_DB_URL}/bacnet/${DEVICE_ID}/${key}.json" \
    -H "Content-Type: application/json" \
    -d "$json")

  if [ "$response" -eq 200 ]; then
    echo "✅ Uploaded $key → $value"
  else
    echo "⚠️  Upload failed for $key (HTTP $response)"
  fi
done < "$VALUES_FILE"

echo "🎉 Done! Check Firebase Console → Realtime Database → Data tab at /bacnet/${DEVICE_ID}/"
