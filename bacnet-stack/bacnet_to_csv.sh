#!/bin/bash
# -----------------------------------------------
# BACnet → CSV logger (local test version)
# Reads all objects from a BACnet MSTP device
# and stores object-name and present-value to a CSV file
# -----------------------------------------------

DEVICE_ID="1234"
BACNET_TOOL="./bin/bacepics"
INTERVAL=600       # seconds between reads
CSV_FILE="bacnet_values.csv"

# Create CSV header if file doesn't exist
if [ ! -f "$CSV_FILE" ]; then
    echo "timestamp,object_name,present_value" > "$CSV_FILE"
fi

while true; do
    echo "[$(date)] Reading BACnet device $DEVICE_ID ..."

    # 1️⃣ Run BACnet EPICS tool and capture output
    OUTPUT=$($BACNET_TOOL -v $DEVICE_ID 2>/dev/null)

    # 2️⃣ Extract object-name and present-value pairs
    echo "$OUTPUT" | \
    awk -v ts="$(date '+%Y-%m-%d %H:%M:%S')" '
      /object-name:/ {
          name=$0
          sub(/.*object-name:[[:space:]]*"/, "", name)
          sub(/".*/, "", name)
      }
      /present-value:/ {
          val=$0
          sub(/.*present-value:[[:space:]]*/, "", val)
          gsub(/ Writable|inactive|off|TRUE|FALSE/, "", val)
          if (name != "" && val != "") {
              # escape commas for CSV safety
              gsub(/,/, ";", name)
              gsub(/,/, ";", val)
              print ts "," name "," val
          }
          name=""
          val=""
      }
    ' >> "$CSV_FILE"

    echo "[$(date)] ✅ Values appended to $CSV_FILE"
    echo "-------------------------------------------"
    sleep $INTERVAL
done
