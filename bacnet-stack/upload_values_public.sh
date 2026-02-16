#!/bin/bash
# upload_values_public.sh
# Usage: ./upload_values_public.sh values.txt
# values.txt has lines like: ANALOG INPUT 1:0.000000 Writable

FIREBASE_DB_URL="https://backnet-fd8ee-default-rtdb.firebaseio.com/"   # <-- replace
DEVICE_ID="1234"
INFILE="${1:-values.txt}"

if [ ! -f "$INFILE" ]; then
  echo "Input file $INFILE not found"
  exit 1
fi

while IFS= read -r line; do
  # split on first colon to name:value
  name="${line%%:*}"
  rest="${line#*:}"

  # clean value: remove trailing words like 'Writable', leading/trailing spaces
  value="$(echo "$rest" | sed -E 's/[[:space:]]+Writable$//; s/^[[:space:]]+//; s/[[:space:]]+$//')"

  # safe firebase key: replace spaces/slashes with underscores
  key="$(echo "$name" | sed -E 's/[^A-Za-z0-9]+/_/g')"

  # create JSON payload with timestamp
  ts="$(date --iso-8601=seconds)"
  json="$(jq -n --arg v "$value" --arg t "$ts" '{value:$v, timestamp:$t}')"

  # upload with PUT to set the value at path /bacnet/<device>/<key>.json
  curl -s -X PUT "${FIREBASE_DB_URL}/bacnet/${DEVICE_ID}/${key}.json" \
       -H "Content-Type: application/json" \
       -d "$json" \
       && echo "uploaded $name -> $value"
done < "$INFILE"
