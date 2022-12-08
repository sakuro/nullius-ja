#!/bin/sh

mod_name="$1"
set -- $(
    curl -s "https://mods.factorio.com/api/mods/${mod_name}" |
    jq -rM '.releases | sort_by(.released_at) | reverse[0] | .download_url, .file_name, .released_at, .sha1, .version'
)

echo "name=mod_name::${mod_name}" >> "${GITHUB_OUTPUT}"
echo "name=download_url::https://mods.factorio.com$1" >> "${GITHUB_OUTPUT}"
echo "name=file_name::$2" >> "${GITHUB_OUTPUT}"
echo "name=released_at::$3" >> "${GITHUB_OUTPUT}"
echo "name=sha1::$4" >> "${GITHUB_OUTPUT}"
echo "name=version::$5" >> "${GITHUB_OUTPUT}"
echo "name=full_name::${mod_name}-$5" >> "${GITHUB_OUTPUT}"
