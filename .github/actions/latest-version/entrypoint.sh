#!/bin/sh

mod_name="$1"
set -- $(
    curl -s "https://mods.factorio.com/api/mods/${mod_name}" |
    jq -rM '.releases | sort_by(.released_at) | reverse[0] | .download_url, .file_name, .released_at, .sha1, .version'
)

echo "::set-output name=mod_name::${mod_name}"
echo "::set-output name=download_url::https://mods.factorio.com$1"
echo "::set-output name=file_name::$2"
echo "::set-output name=released_at::$3"
echo "::set-output name=sha1::$4"
echo "::set-output name=version::$5"
echo "::set-output name=full_name::${mod_name}-$5"
