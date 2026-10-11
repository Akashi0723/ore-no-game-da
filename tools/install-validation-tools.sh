#!/usr/bin/env bash
# Install pinned upstream tools without changing the repository's dependencies.
set -euo pipefail

tool_dir="${WILDBOUND_TOOL_DIR:-/workspace/.wildbound-tools}"
mkdir -p "$tool_dir/rojo" "$tool_dir/luau"

download_verified() {
  local url="$1" archive="$2" expected="$3"
  curl --fail --silent --show-error --location "$url" --output "$archive"
  printf '%s  %s\n' "$expected" "$archive" | sha256sum --check --status
}

download_verified \
  "https://github.com/rojo-rbx/rojo/releases/download/v7.7.1/rojo-7.7.1-linux-x86_64.zip" \
  "$tool_dir/rojo.zip" \
  "00feb4fa0829a1dd72b49df2639da519a352bfe13cadcd83969e2ba2bb5693c4"
download_verified \
  "https://github.com/luau-lang/luau/releases/download/0.742/luau-ubuntu.zip" \
  "$tool_dir/luau.zip" \
  "152058b98c60ff1f5b5ec9bca0b8eb37793cae161dd3a05608cc3d8738ba1a4d"

unzip -oq "$tool_dir/rojo.zip" -d "$tool_dir/rojo"
unzip -oq "$tool_dir/luau.zip" -d "$tool_dir/luau"
chmod +x "$tool_dir/rojo/rojo" "$tool_dir"/luau/luau*
"$tool_dir/rojo/rojo" --version
printf 'Luau 0.742 installed; both archives verified against upstream GitHub SHA-256.\n'
