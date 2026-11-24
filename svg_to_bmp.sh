#!/usr/bin/env bash

set -euo pipefail

usage() {
    echo "Usage: $0 <input.svg> [output.bmp]"
    echo "If output.bmp is omitted, it is created beside the input file."
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

if [[ $# -lt 1 || $# -gt 2 ]]; then
    usage >&2
    exit 1
fi

input=$1
output=${2:-${input%.*}.bmp}

if [[ ! -f "$input" ]]; then
    echo "Error: input file not found: $input" >&2
    exit 1
fi

if ! command -v magick >/dev/null 2>&1; then
    echo "Error: ImageMagick's 'magick' command is required." >&2
    exit 1
fi

magick "$input" \
    -background none \
    -resize 24x24 \
    -gravity center \
    -extent 24x24 \
    -alpha on \
    -type TrueColorAlpha \
    "BMP3:$output"

echo "Created $output"
