#!/bin/sh

set -ue

INIT_UPLOAD_ENDPOINT_URL="https://mods.factorio.com/api/v2/mods/releases/init_upload"

mod_name="$1"
mod_version="$2"
zip_name="$3"
api_key="$4"

set -- $(
  curl -s -X POST -H "Authorization: Bearer $api_key" -F "mod=$mod_name" "$INIT_UPLOAD_ENDPOINT_URL" |
  jq -rM '.upload_url, .error, .message'
)

upload_url="$1"
error="$2"
message="$3"

[[ "$error" = null ]] || {
  echo "$error: $message"
  exit 1
}

set -- $(
  curl -s -X POST -F file=@- "$upload_url" < $zip_name |
  jq -rM '.success, .error, .message'
)

success="$1"
error="$2"
message="$3"

[[ "$error" = null ]] || {
  echo "$error: $message"
  exit 1
}
