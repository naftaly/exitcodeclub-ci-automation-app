#!/bin/bash
#
# Upload System Symbols from Xcode
#
# This script extracts iOS system symbols from Xcode's DeviceSupport folder
# or simulator runtimes and uploads them to the KSCrash service for symbolication.
#
# Usage:
#   ./upload-system-symbols.sh --list                        # List available device iOS versions
#   ./upload-system-symbols.sh --version <version>           # Upload device symbols for a version
#   ./upload-system-symbols.sh --build <build>               # Upload device symbols for a build number
#   ./upload-system-symbols.sh --simulator --list            # List available simulator runtimes
#   ./upload-system-symbols.sh --simulator --version <ver>   # Upload simulator symbols
#   ./upload-system-symbols.sh --simulator --build <build>   # Upload simulator symbols by build
#   ./upload-system-symbols.sh --dry-run --version <version> # Preview without uploading
#
# Examples:
#   ./upload-system-symbols.sh --list
#   ./upload-system-symbols.sh --version 18.0
#   ./upload-system-symbols.sh --build 23C55
#   ./upload-system-symbols.sh --simulator --list
#   ./upload-system-symbols.sh --simulator --version 26.2
#   ./upload-system-symbols.sh --simulator --build 23C54
#   ./upload-system-symbols.sh --simulator --dry-run --version 26.2
#
# Requirements:
#   - macOS with Xcode installed
#   - For device symbols: iOS device must have been connected to Xcode at least once
#   - For simulator symbols: simulator runtime must be downloaded
#   - curl, xcrun (dwarfdump), zip, jq, bc

set -e

# Server URL (automatically set when downloaded from the service)
BACKEND_URL="https://kscrash-api-765738384004.us-central1.run.app"

DEVICE_SUPPORT_DIR="$HOME/Library/Developer/Xcode/iOS DeviceSupport"

show_help() {
    echo "Upload System Symbols from Xcode"
    echo ""
    echo "Server: $BACKEND_URL"
    echo ""
    echo "Usage:"
    echo "  $0 --list                              List available device iOS versions"
    echo "  $0 --version <version>                 Upload device symbols for a version"
    echo "  $0 --build <build>                     Upload device symbols for a build number"
    echo "  $0 --simulator --list                  List available simulator runtimes"
    echo "  $0 --simulator --version <version>     Upload simulator symbols for a version"
    echo "  $0 --simulator --build <build>         Upload simulator symbols by build number"
    echo "  $0 --dry-run --version <version>       Preview without uploading"
    echo ""
    echo "Examples:"
    echo "  $0 --list"
    echo "  $0 --version 18.0"
    echo "  $0 --build 23C55"
    echo "  $0 --simulator --list"
    echo "  $0 --simulator --version 26.2"
    echo "  $0 --simulator --build 23C54"
    echo "  $0 --simulator --dry-run --version 26.2"
    echo ""
    echo "Options:"
    echo "  --list, -l       List available iOS versions"
    echo "  --version, -v    iOS version to upload (e.g., 18.0, 17.5)"
    echo "  --build, -b      Build number to upload (e.g., 23C55, 22G86)"
    echo "  --simulator, -s  Use simulator runtimes instead of device symbols"
    echo "  --dry-run, -n    Scan and show what would be uploaded, but don't upload"
    echo "  --help, -h       Show this help message"
}

list_versions() {
    if [[ ! -d "$DEVICE_SUPPORT_DIR" ]]; then
        echo "Error: Xcode DeviceSupport directory not found at:"
        echo "  $DEVICE_SUPPORT_DIR"
        echo ""
        echo "Make sure you have Xcode installed and have connected an iOS device."
        exit 1
    fi

    echo "Available iOS versions in DeviceSupport:"
    echo ""
    for dir in "$DEVICE_SUPPORT_DIR"/*; do
        if [[ -d "$dir" && -d "$dir/Symbols" ]]; then
            version=$(basename "$dir")
            echo "  $version"
        fi
    done
}

list_simulator_versions() {
    local JSON
    JSON=$(xcrun simctl list runtimes -j 2>/dev/null) || {
        echo "Error: xcrun simctl list runtimes failed"
        echo "Make sure Xcode is installed."
        exit 1
    }

    echo "Available iOS simulator runtimes:"
    echo ""
    echo "$JSON" | jq -r '
        .runtimes[]
        | select(.platform == "iOS" and .isAvailable)
        | "  iOS \(.version) (\(.buildversion))"
    '
}

# Find the simulator RuntimeRoot for a given iOS version or build number.
# Sets SYMBOLS_DIR, MATCHED_VERSION, and FULL_VERSION.
find_simulator_runtime() {
    local VERSION="$1"
    local BUILD="$2"

    local JSON
    JSON=$(xcrun simctl list runtimes -j 2>/dev/null) || {
        echo "Error: xcrun simctl list runtimes failed"
        exit 1
    }

    local RESULT
    if [[ -n "$VERSION" ]]; then
        RESULT=$(echo "$JSON" | jq -r --arg v "$VERSION" '
            .runtimes[]
            | select(.platform == "iOS" and .isAvailable and (.version | startswith($v)) and .runtimeRoot)
            | "\(.runtimeRoot)|\(.version)|\(.buildversion)"
        ' | head -1)
    elif [[ -n "$BUILD" ]]; then
        RESULT=$(echo "$JSON" | jq -r --arg b "$BUILD" '
            .runtimes[]
            | select(.platform == "iOS" and .isAvailable and (.buildversion | startswith($b)) and .runtimeRoot)
            | "\(.runtimeRoot)|\(.version)|\(.buildversion)"
        ' | head -1)
    fi

    if [[ -z "$RESULT" ]]; then
        return 1
    fi

    IFS='|' read -r SYMBOLS_DIR rt_version rt_build <<< "$RESULT"
    MATCHED_VERSION="iOS $rt_version (Simulator)"
    FULL_VERSION="$rt_version ($rt_build)"
    return 0
}

upload_version() {
    local VERSION="$1"
    local BUILD="$2"
    local DRY_RUN="$3"
    local SIMULATOR="$4"

    if [[ -z "$VERSION" ]] && [[ -z "$BUILD" ]]; then
        echo "Error: iOS version or build is required (use --version or --build)"
        show_help
        exit 1
    fi

    SYMBOLS_DIR=""
    MATCHED_VERSION=""
    FULL_VERSION=""

    if [[ "$SIMULATOR" == "true" ]]; then
        # Find matching simulator runtime
        if ! find_simulator_runtime "$VERSION" "$BUILD"; then
            echo "Error: No simulator runtime found for iOS ${VERSION}${BUILD}"
            echo ""
            echo "Run '$0 --simulator --list' to see available runtimes."
            exit 1
        fi
    else
        # Find matching DeviceSupport directory
        if [[ ! -d "$DEVICE_SUPPORT_DIR" ]]; then
            echo "Error: Xcode DeviceSupport directory not found"
            exit 1
        fi

        for dir in "$DEVICE_SUPPORT_DIR"/*; do
            if [[ -d "$dir" ]]; then
                dir_name=$(basename "$dir")
                # Extract version number (e.g., "26.0" from "iPhone17,1 26.0 (23A340)")
                dir_version=$(echo "$dir_name" | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)
                # Extract build number (e.g., "23A340" from "iPhone17,1 26.0 (23A340)")
                dir_build=$(echo "$dir_name" | grep -oE '\(([^)]+)\)' | tr -d '()')
                if [[ -n "$VERSION" && "$dir_version" == "$VERSION"* ]] || [[ -n "$BUILD" && "$dir_build" == "$BUILD"* ]]; then
                    if [[ -d "$dir/Symbols" ]]; then
                        SYMBOLS_DIR="$dir/Symbols"
                        MATCHED_VERSION="$dir_name"
                        break
                    fi
                fi
            fi
        done

        if [[ -z "$SYMBOLS_DIR" ]]; then
            echo "Error: No DeviceSupport symbols found for iOS ${VERSION}${BUILD}"
            echo ""
            echo "Run '$0 --list' to see available versions."
            exit 1
        fi

        # Extract version with build (e.g., "26.2 (23C55)" from "iPhone18,4 26.2 (23C55)")
        FULL_VERSION=$(echo "$MATCHED_VERSION" | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?\s*\([^)]+\)')
    fi

    echo "Found: $MATCHED_VERSION"
    echo "Version: $FULL_VERSION"
    echo "Symbols: $SYMBOLS_DIR"
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "Mode: DRY RUN (no uploads)"
    fi
    echo ""

    # Create temp directory for work
    WORK_DIR=$(mktemp -d)
    trap "rm -rf '$WORK_DIR'" EXIT

    echo "Scanning for Mach-O binaries with symbols..."

    FOUND_COUNT=0
    SCANNED_COUNT=0
    UPLOADED_COUNT=0
    SKIPPED_COUNT=0
    FAILED_COUNT=0
    TOTAL_BYTES=0

    # For simulator runtimes, only scan directories that contain dylibs/frameworks
    # (the full RuntimeRoot has ~500K files, most are resources)
    if [[ "$SIMULATOR" == "true" ]]; then
        SCAN_DIRS=()
        for subdir in usr/lib System/Library/Frameworks System/Library/PrivateFrameworks; do
            if [[ -d "$SYMBOLS_DIR/$subdir" ]]; then
                SCAN_DIRS+=("$SYMBOLS_DIR/$subdir")
            fi
        done
        if [[ ${#SCAN_DIRS[@]} -eq 0 ]]; then
            echo "Error: No framework/library directories found in simulator runtime"
            exit 1
        fi
    else
        SCAN_DIRS=("$SYMBOLS_DIR")
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "Mode: DRY RUN — scanning only, no uploads"
        echo ""
    fi

    # Batch configuration
    # Cloud Run has 32MB request limit; keep batches well under that
    MAX_BATCH_SIZE_MB=20
    MAX_BATCH_SIZE_BYTES=$((MAX_BATCH_SIZE_MB * 1024 * 1024))
    MAX_SINGLE_FILE_MB=15
    MAX_SINGLE_FILE_BYTES=$((MAX_SINGLE_FILE_MB * 1024 * 1024))

    BATCH_DIR="$WORK_DIR/batch"
    mkdir -p "$BATCH_DIR"
    BATCH_COUNT=0
    BATCH_SIZE_BYTES=0
    BATCH_NUM=0
    DIRECT_UPLOAD_COUNT=0

    # Function to upload current batch
    upload_batch() {
        if [[ $BATCH_COUNT -eq 0 ]]; then
            return
        fi

        ((BATCH_NUM++))
        ORIGINAL_COUNT=$BATCH_COUNT

        # Extract UUIDs from batch directory filenames (format: {uuid}_{name})
        UUIDS_JSON=$(ls "$BATCH_DIR" | sed 's/_.*//' | jq -R -s -c 'split("\n") | map(select(length > 0))')

        # Check which UUIDs already exist
        CHECK_RESPONSE=$(curl -s -X POST \
            -H "Content-Type: application/json" \
            -d "{\"uuids\": $UUIDS_JSON}" \
            "$BACKEND_URL/api/system-symbols/check" 2>/dev/null)

        # Get list of existing UUIDs and remove them from batch
        EXISTING_UUIDS=$(echo "$CHECK_RESPONSE" | jq -r '.existing[]' 2>/dev/null)
        SKIPPED_IN_BATCH=0
        for existing_uuid in $EXISTING_UUIDS; do
            # Find and remove file with this UUID prefix
            for f in "$BATCH_DIR"/${existing_uuid}_*; do
                if [[ -f "$f" ]]; then
                    rm -f "$f"
                    ((SKIPPED_IN_BATCH++))
                    ((SKIPPED_COUNT++))
                    ((BATCH_COUNT--))
                fi
            done
        done

        # If all files were skipped, just report and return
        if [[ $BATCH_COUNT -eq 0 ]]; then
            echo "  Batch $BATCH_NUM ($ORIGINAL_COUNT files): $SKIPPED_IN_BATCH exist, skipped"
            BATCH_SIZE_BYTES=0
            return
        fi

        # Recalculate batch size
        BATCH_SIZE_BYTES=0
        for f in "$BATCH_DIR"/*; do
            if [[ -f "$f" ]]; then
                FILE_SIZE=$(stat -f%z "$f" 2>/dev/null || stat -c%s "$f" 2>/dev/null || echo "0")
                BATCH_SIZE_BYTES=$((BATCH_SIZE_BYTES + FILE_SIZE))
            fi
        done

        # Create zip from remaining files
        ZIP_FILE="$WORK_DIR/batch.zip"
        rm -f "$ZIP_FILE"
        (cd "$BATCH_DIR" && zip -q "$ZIP_FILE" *)

        # Upload with progress bar that gets replaced by result
        ENCODED_VERSION=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$FULL_VERSION'))")
        BATCH_SIZE_MB=$(echo "scale=1; $BATCH_SIZE_BYTES / 1024 / 1024" | bc)
        BATCH_LABEL="Batch $BATCH_NUM ($BATCH_COUNT new + $SKIPPED_IN_BATCH exist, ${BATCH_SIZE_MB}MB)"

        # Show progress during upload (curl progress bar to tty)
        echo -n "  $BATCH_LABEL: "
        curl --progress-bar -o /tmp/upload_response.json -w "%{http_code}" -X POST \
            -F "file=@$ZIP_FILE" \
            "$BACKEND_URL/api/system-symbols?ios_version=$ENCODED_VERSION" \
            2>/dev/tty >/tmp/upload_http_code
        HTTP_CODE=$(cat /tmp/upload_http_code 2>/dev/null || echo "000")
        RESPONSE=$(cat /tmp/upload_response.json 2>/dev/null || echo "[]")

        # Count results from response
        BATCH_SUCCESS=$(echo "$RESPONSE" | jq '[.[] | select(.success == true)] | length' 2>/dev/null || echo "0")
        BATCH_UPLOADED=$BATCH_SUCCESS
        BATCH_FAILED=$((BATCH_COUNT - BATCH_SUCCESS))

        UPLOADED_COUNT=$((UPLOADED_COUNT + BATCH_UPLOADED))
        FAILED_COUNT=$((FAILED_COUNT + BATCH_FAILED))

        # Move up one line, clear it, and print final result
        printf "\033[1A\033[2K  $BATCH_LABEL: "
        if [[ "$HTTP_CODE" != "200" ]]; then
            echo "Error (HTTP $HTTP_CODE)"
        else
            echo "$BATCH_UPLOADED new, $BATCH_FAILED failed"
        fi

        # Clear batch directory for next batch
        rm -f "$BATCH_DIR"/*
        BATCH_COUNT=0
        BATCH_SIZE_BYTES=0
    }

    # Scan and upload as we go — no separate collection pass
    while IFS= read -r -d '' binary_path; do
        BINARY_NAME=$(basename "$binary_path")

        # Skip known non-binary files by extension
        case "$BINARY_NAME" in
            *.plist|*.png|*.jpg|*.jpeg|*.gif|*.strings|*.nib|*.storyboardc|*.car|*.mom|*.momd|*.dat|*.db|*.json|*.xml|*.html|*.css|*.js|*.ttf|*.otf|*.wav|*.mp3|*.m4a|*.caf|*.aif|*.aiff|*.pdf|*.lproj|*.xcassets|*.metallib|*.mlmodelc|*.tbd|*.swiftmodule|*.swiftinterface|*.abi.json|*.swiftsourceinfo|*.private.swiftinterface)
                continue
                ;;
        esac

        ((SCANNED_COUNT++))

        # Show progress every 1000 files
        if [[ $((SCANNED_COUNT % 1000)) -eq 0 ]]; then
            echo "  Scanned $SCANNED_COUNT files, found $FOUND_COUNT symbols, uploaded $UPLOADED_COUNT..."
        fi

        # Quick check if it's a Mach-O file
        if ! file "$binary_path" 2>/dev/null | grep -q "Mach-O"; then
            continue
        fi

        # Get UUID using dwarfdump
        UUID=$(xcrun dwarfdump --uuid "$binary_path" 2>/dev/null | grep -o '[0-9A-F-]\{36\}' | tr -d '-' | head -1)

        if [[ -z "$UUID" ]]; then
            continue
        fi

        ((FOUND_COUNT++))
        FILE_SIZE=$(stat -f%z "$binary_path" 2>/dev/null || stat -c%s "$binary_path" 2>/dev/null || echo "0")
        TOTAL_BYTES=$((TOTAL_BYTES + FILE_SIZE))

        if [[ "$DRY_RUN" == "true" ]]; then
            continue
        fi

        # Large files: upload directly to GCS via signed URL
        if [[ $FILE_SIZE -gt $MAX_SINGLE_FILE_BYTES ]]; then
            # Upload any pending batch first
            upload_batch

            FILE_SIZE_MB=$(echo "scale=1; $FILE_SIZE / 1024 / 1024" | bc)
            ((BATCH_NUM++))

            # Get signed upload URL
            URL_RESPONSE=$(curl -s -X POST \
                -H "Content-Type: application/json" \
                -d "{\"uuid\": \"$UUID\", \"binary_name\": \"$BINARY_NAME\", \"file_size\": $FILE_SIZE}" \
                "$BACKEND_URL/api/system-symbols/upload-url" 2>/dev/null)

            # Check for errors (409 = already exists)
            if echo "$URL_RESPONSE" | jq -e '.detail' >/dev/null 2>&1; then
                ERROR_DETAIL=$(echo "$URL_RESPONSE" | jq -r '.detail')
                if [[ "$ERROR_DETAIL" == *"already exists"* ]]; then
                    ((SKIPPED_COUNT++))
                    echo "  Batch $BATCH_NUM (1 file, ${FILE_SIZE_MB}MB): 0 new, 1 exist, 0 failed"
                else
                    ((FAILED_COUNT++))
                    echo "  Batch $BATCH_NUM (1 file, ${FILE_SIZE_MB}MB): 0 new, 0 exist, 1 failed"
                fi
                continue
            fi

            # Extract upload URL and GCS path
            UPLOAD_URL=$(echo "$URL_RESPONSE" | jq -r '.upload_url')
            GCS_PATH=$(echo "$URL_RESPONSE" | jq -r '.gcs_path')

            if [[ -z "$UPLOAD_URL" ]] || [[ "$UPLOAD_URL" == "null" ]]; then
                ((FAILED_COUNT++))
                echo "  Batch $BATCH_NUM (1 file, ${FILE_SIZE_MB}MB): 0 new, 0 exist, 1 failed"
                continue
            fi

            # Upload directly to GCS with progress bar
            BATCH_LABEL="Batch $BATCH_NUM (1 file, ${FILE_SIZE_MB}MB)"
            echo -n "  $BATCH_LABEL: "
            curl --progress-bar -o /dev/null -w "%{http_code}" -X PUT \
                -H "Content-Type: application/octet-stream" \
                --data-binary "@$binary_path" \
                "$UPLOAD_URL" \
                2>/dev/tty >/tmp/upload_http_code
            HTTP_CODE=$(cat /tmp/upload_http_code 2>/dev/null || echo "000")

            # Move up and clear progress line
            printf "\033[1A\033[2K  $BATCH_LABEL: "

            if [[ "$HTTP_CODE" != "200" ]]; then
                ((FAILED_COUNT++))
                echo "0 new, 1 failed (HTTP $HTTP_CODE)"
                continue
            fi

            # Register the uploaded file
            REG_RESPONSE=$(curl -s -X POST \
                -H "Content-Type: application/json" \
                -d "{\"uuid\": \"$UUID\", \"binary_name\": \"$BINARY_NAME\", \"gcs_path\": \"$GCS_PATH\", \"ios_version\": \"$FULL_VERSION\"}" \
                "$BACKEND_URL/api/system-symbols/register" 2>/dev/null)

            if echo "$REG_RESPONSE" | jq -e '.success == true' >/dev/null 2>&1; then
                ((UPLOADED_COUNT++))
                ((DIRECT_UPLOAD_COUNT++))
                echo "1 new, 0 failed"
            else
                ((FAILED_COUNT++))
                echo "0 new, 1 failed (registration error)"
            fi
            continue
        fi

        # If adding this file would exceed batch size, upload current batch first
        if [[ $BATCH_COUNT -gt 0 ]] && [[ $((BATCH_SIZE_BYTES + FILE_SIZE)) -gt $MAX_BATCH_SIZE_BYTES ]]; then
            upload_batch
        fi

        # Copy file with UUID prefix to batch directory
        cp "$binary_path" "$BATCH_DIR/${UUID}_${BINARY_NAME}" 2>/dev/null || {
            echo "    Failed to copy: $BINARY_NAME"
            continue
        }
        ((BATCH_COUNT++))
        BATCH_SIZE_BYTES=$((BATCH_SIZE_BYTES + FILE_SIZE))
    done < <(find "${SCAN_DIRS[@]}" -type f -print0 2>/dev/null)

    # Upload any remaining files in the last batch
    upload_batch

    TOTAL_MB=$(echo "scale=1; $TOTAL_BYTES / 1024 / 1024" | bc)
    echo ""
    echo "Scanned: $SCANNED_COUNT files"
    echo "Found: $FOUND_COUNT Mach-O binaries with UUIDs (${TOTAL_MB}MB total)"

    if [[ "$DRY_RUN" == "true" ]]; then
        echo ""
        echo "Would upload $FOUND_COUNT symbols. Run without --dry-run to upload."
    else
        echo ""
        echo "Done."
        echo "  Uploaded: $UPLOADED_COUNT"
        if [[ $DIRECT_UPLOAD_COUNT -gt 0 ]]; then
            echo "    (including $DIRECT_UPLOAD_COUNT large files via direct upload)"
        fi
        echo "  Skipped (already exists): $SKIPPED_COUNT"
        echo "  Failed: $FAILED_COUNT"
        echo ""
        echo "Re-symbolicate any reports to use the new symbols."
    fi
}

# Parse arguments
if [[ $# -eq 0 ]]; then
    show_help
    exit 0
fi

VERSION=""
BUILD=""
DRY_RUN="false"
SIMULATOR="false"
LIST="false"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --list|-l)
            LIST="true"
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        --version|-v)
            VERSION="$2"
            shift 2
            ;;
        --simulator|-s)
            SIMULATOR="true"
            shift
            ;;
        --build|-b)
            BUILD="$2"
            shift 2
            ;;
        --dry-run|-n)
            DRY_RUN="true"
            shift
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

if [[ "$LIST" == "true" ]]; then
    if [[ "$SIMULATOR" == "true" ]]; then
        list_simulator_versions
    else
        list_versions
    fi
    exit 0
fi

upload_version "$VERSION" "$BUILD" "$DRY_RUN" "$SIMULATOR"
