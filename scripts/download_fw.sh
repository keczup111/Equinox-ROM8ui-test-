#!/usr/bin/env bash

# Copyright (C) 2023 Salvo Giangreco
# License: GNU GPL v3 or later

set -e

# === CONFIGURATION ===
export ODIN_DIR="$HOME/firmwares"

# Source: Galaxy S23 (Snapdragon EU)
SOURCE_FIRMWARE="SM-S918B/EUX/000000000000000"

# Target: Galaxy S21 FE (Snapdragon EU)
TARGET_FIRMWARE="SM-G990B2/EUX/000000000000000"

# Additional firmwares (optional, colon-separated)
SOURCE_EXTRA_FIRMWARES=""
TARGET_EXTRA_FIRMWARES=""

# === FUNCTIONS ===
GET_LATEST_FIRMWARE() {
    # The MODEL and REGION variables must be available in this function
    curl -s --retry 5 --retry-delay 5 "https://fota-cloud-dn.ospserver.net/firmware/$REGION/$MODEL/version.xml" \
        | grep latest | sed 's/^[^>]*>//' | sed 's/<.*//'
}

DOWNLOAD_FIRMWARE() {
    local PDR
    PDR="$(pwd)"

    cd "$ODIN_DIR"
    # Make sure the 'samfirm' utility is installed and available in your PATH
    { samfirm -m "$MODEL" -r "$REGION" > /dev/null; } 2>&1 \
        && touch "$ODIN_DIR/${MODEL}_${REGION}/.downloaded" \
        || exit 1
    [ -f "$ODIN_DIR/${MODEL}_${REGION}/.downloaded" ] && {
        echo -n "$(find "$ODIN_DIR/${MODEL}_${REGION}" -name "AP*" -exec basename {} \; | cut -d "_" -f 2)/"
        echo -n "$(find "$ODIN_DIR/${MODEL}_${REGION}" -name "CSC*" -exec basename {} \; | cut -d "_" -f 3)/"
        echo -n "$(find "$ODIN_DIR/${MODEL}_${REGION}" -name "CP*" -exec basename {} \; | cut -d "_" -f 2)"
    } >> "$ODIN_DIR/${MODEL}_${REGION}/.downloaded"

    echo ""
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
    # Correctly parse the model and region from the string
    MODEL=$(echo -n "$i" | cut -d "/" -f 1)
    REGION=$(echo -n "$i" | cut -d "/" -f 2)

    if [ -z "$MODEL" ] || [ -z "$REGION" ]; then
        echo "Error: Could not determine model or region from '$i'. Skipping."
        continue
    fi

    if [ -f "$ODIN_DIR/${MODEL}_${REGION}/.downloaded" ]; then
        LATEST_VERSION=$(GET_LATEST_FIRMWARE)
        [ -z "$LATEST_VERSION" ] && continue
        if [[ "$LATEST_VERSION" != "$(cat "$ODIN_DIR/${MODEL}_${REGION}/.downloaded")" ]]; then
            if $FORCE; then
                echo "- Updating firmware for $MODEL with CSC $REGION..."
                rm -rf "$ODIN_DIR/${MODEL}_${REGION}" && DOWNLOAD_FIRMWARE
            else
                echo "- Firmware for $MODEL with CSC $REGION is already downloaded."
                echo "  A newer version is available."
                echo -e "  To download, remove the directory or use the \"--force\" option\n"
                continue
            fi
        else
            echo -e "- Firmware for $MODEL with CSC $REGION is up to date. Skipping...\n"
            continue
        fi
    else
        echo "- Downloading firmware for $MODEL with CSC $REGION..."
        rm -rf "$ODIN_DIR/${MODEL}_${REGION}" && DOWNLOAD_FIRMWARE
    fi
done

exit 0
