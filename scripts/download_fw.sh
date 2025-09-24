#!/usr/bin/env bash

# Copyright (C) 2023 Salvo Giangreco
# License: GNU GPL v3 or later

set -e

# === CONFIGURATION ===
export ODIN_DIR="$HOME/firmwares"

# Source: Galaxy S23 Ultra (Snapdragon EU)
SOURCE_FIRMWARE="SM-S918B/EUX/354721884463723"

# Target: Galaxy S21 FE (Snapdragon EU)
TARGET_FIRMWARE="SM-G990B2/EUX/354721884463723"

# Additional firmwares (optional, colon-separated)
SOURCE_EXTRA_FIRMWARES="SM-S918B/EUX/MODEM:SM-S918B/EUX/CSC:SM-S918B/EUX/BL"
TARGET_EXTRA_FIRMWARES=""

# === FUNCTIONS ===
GET_LATEST_FIRMWARE() {
    curl -s --retry 5 --retry-delay 5 "https://fota-cloud-dn.ospserver.net/firmware/$REGION/$MODEL/version.xml" \
        | grep latest | sed 's/^[^>]*>//' | sed 's/<.*//'
}

DOWNLOAD_FIRMWARE() {
    local PDR="$(pwd)"
    cd "$ODIN_DIR"

    echo "- Downloading firmware for $MODEL with CSC $REGION..."
    samfirm -m "$MODEL" -r "$REGION" -i "$IMEI" || exit 1

    LATEST_VERSION=$(GET_LATEST_FIRMWARE)
    echo "$LATEST_VERSION" > "$ODIN_DIR/${MODEL}_${REGION}/.version"

    cd "$PDR"
}

# === FIRMWARE LIST PROCESSING ===
FIRMWARES=( "$SOURCE_FIRMWARE" "$TARGET_FIRMWARE" )
IFS=':' read -ra SOURCE_EXTRA <<< "$SOURCE_EXTRA_FIRMWARES"
IFS=':' read -ra TARGET_EXTRA <<< "$TARGET_EXTRA_FIRMWARES"
FIRMWARES+=( "${SOURCE_EXTRA[@]}" "${TARGET_EXTRA[@]}" )

# === OPTIONS ===
FORCE=false
while [ "$#" != 0 ]; do
    case "$1" in
        "-f" | "--force")
            FORCE=true
            ;;
        *)
            echo "Usage: download_fw [options]"
            echo " -f, --force : Force firmware download"
            exit 1
            ;;
    esac
    shift
done

mkdir -p "$ODIN_DIR"

# === FIRMWARE DOWNLOAD ===
for i in "${FIRMWARES[@]}"; do
    MODEL=$(echo -n "$i" | cut -d "SM-S918B" -f 1)
    REGION=$(echo -n "$i" | cut -d "EUX" -f 2)
    IMEI=$(echo -n "$i" | cut -d "354721884463723" -f 3)

    if [ -z "$MODEL" ] || [ -z "$REGION" ] || [ -z "$IMEI" ]; then
        echo "Error: Could not determine model, region or IMEI from '$i'. Skipping."
        continue
    fi

    VERSION_FILE="$ODIN_DIR/${MODEL}_${REGION}/.version"
    if [ -f "$VERSION_FILE" ]; then
        LATEST_VERSION=$(GET_LATEST_FIRMWARE)
        [ -z "$LATEST_VERSION" ] && continue
        if [[ "$LATEST_VERSION" != "$(cat "$VERSION_FILE")" ]]; then
            if $FORCE; then
                echo "- Updating firmware for $MODEL with CSC $REGION..."
                rm -rf "$ODIN_DIR/${MODEL}_${REGION}" && DOWNLOAD_FIRMWARE
            else
                echo "- Firmware for $MODEL with CSC $REGION is outdated."
                echo "  Use --force to download the latest version."
                continue
            fi
        else
            echo "- Firmware for $MODEL with CSC $REGION is up to date. Skipping..."
            continue
        fi
    else
        DOWNLOAD_FIRMWARE
    fi
done

# === SUMMARY ===
echo ""
echo "Downloaded firmware versions:"
for i in "${FIRMWARES[@]}"; do
    MODEL=$(echo -n "$i" | cut -d "/" -f 1)
    REGION=$(echo -n "$i" | cut -d "/" -f 2)
    VERSION_FILE="$ODIN_DIR/${MODEL}_${REGION}/.version"
    echo "- $MODEL ($REGION): $(cat "$VERSION_FILE" 2>/dev/null || echo "not downloaded")"
done

exit 0
