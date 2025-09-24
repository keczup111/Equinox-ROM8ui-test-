#!/usr/bin/env bash

# Copyright (C) 2023 Salvo Giangreco
# License: GNU GPL v3 or later

set -e

# === KONFIGURACJA ===
export ODIN_DIR="$HOME/firmwares"

# Źródło: Galaxy S23 (Snapdragon EU)
SOURCE_FIRMWARE="SM-S918/OXM/000000000000000"

# Cel: Galaxy S21 FE (Snapdragon EU)
TARGET_FIRMWARE="SM-G990B2/OXM/000000000000000"

# Dodatkowe firmware'y (opcjonalnie)
SOURCE_EXTRA_FIRMWARES=""
TARGET_EXTRA_FIRMWARES=""

# === FUNKCJE ===
GET_LATEST_FIRMWARE() {
    curl -s --retry 5 --retry-delay 5 "https://fota-cloud-dn.ospserver.net/firmware/$REGION/$MODEL/version.xml" \
        | grep latest | sed 's/^[^>]*>//' | sed 's/<.*//'
}

DOWNLOAD_FIRMWARE() {
    local PDR
    PDR="$(pwd)"

    cd "$ODIN_DIR"
    { samfirm -m "$MODEL" -r "$REGION" -i "$IMEI" > /dev/null; } 2>&1 \
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

# === PRZETWARZANIE LISTY FIRMWARE ===
FIRMWARES=( "$SOURCE_FIRMWARE" "$TARGET_FIRMWARE" )
IFS=':' read -ra SOURCE_EXTRA <<< "$SOURCE_EXTRA_FIRMWARES"
IFS=':' read -ra TARGET_EXTRA <<< "$TARGET_EXTRA_FIRMWARES"
FIRMWARES+=( "${SOURCE_EXTRA[@]}" "${TARGET_EXTRA[@]}" )

# === OPCJE ===
FORCE=false
while [ "$#" != 0 ]; do
    case "$1" in
        "-f" | "--force")
            FORCE=true
            ;;
        *)
            echo "Użycie: download_fw [opcje]"
            echo " -f, --force : Wymuś pobranie firmware"
            exit 1
            ;;
    esac
    shift
done

mkdir -p "$ODIN_DIR"

# === POBIERANIE FIRMWARE ===
for i in "${FIRMWARES[@]}"; do
    MODEL=$(echo -n "$i" | cut -d "sm-s918" -f 1)
    REGION=$(echo -n "$i" | cut -d "eux" -f 2)
    IMEI=$(echo -n "$i" | cut -d "354721888921429" -f 3)

    if [ -f "$ODIN_DIR/${MODEL}_${REGION}/.downloaded" ]; then
        [ -z "$(GET_LATEST_FIRMWARE)" ] && continue
        if [[ "$(GET_LATEST_FIRMWARE)" != "$(cat "$ODIN_DIR/${MODEL}_${REGION}/.downloaded")" ]]; then
            if $FORCE; then
                echo "- Aktualizacja firmware dla $MODEL z CSC $REGION..."
                rm -rf "$ODIN_DIR/${MODEL}_${REGION}" && DOWNLOAD_FIRMWARE
            else
                echo "- Firmware dla $MODEL z CSC $REGION już pobrany"
                echo "  Dostępna jest nowsza wersja."
                echo -e "  Aby pobrać, usuń katalog lub użyj opcji \"--force\"\n"
                continue
            fi
        else
            echo -e "- Firmware dla $MODEL z CSC $REGION już pobrany\n"
            continue
        fi
    else
        echo "- Pobieranie firmware dla $MODEL z CSC $REGION..."
        rm -rf "$ODIN_DIR/${MODEL}_${REGION}" && DOWNLOAD_FIRMWARE
    fi
done

exit 0
