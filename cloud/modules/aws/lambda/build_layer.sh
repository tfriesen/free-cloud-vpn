#!/usr/bin/env bash
# Build script for an AWS Lambda layer containing Python packages (e.g. requests).
#
# Usage:
#   ./build_layer.sh [output_zip] [python_version] [packages...]
# Examples:
#   ./build_layer.sh requests_layer.zip 3.12 requests
#   ./build_layer.sh                # builds requests_layer.zip for python3.12 with 'requests'
#
# Notes:
# - The script installs packages into the layout expected by AWS Lambda layers:
#   python/lib/python<ver>/site-packages
# - For layers targeting a specific architecture (e.g. arm64) you should build
#   on a compatible environment (Amazon Linux 2 / manylinux image or the target
#   architecture). Otherwise binary wheels may be incompatible.
# - To build for arm64 on x86_64 hosts consider using Docker with an appropriate
#   base image (amazonlinux or manylinux) or build on an arm64 machine.

set -euo pipefail

OUTPUT_ZIP=${1:-requests_layer.zip}
PYVER=${2:-3.12}
shift 2 || true

if [ "$#" -gt 0 ]; then
  PACKAGES="$*"
else
  PACKAGES="requests"
fi

echo "Building layer: output=$OUTPUT_ZIP  python=$PYVER  packages=$PACKAGES"

BUILD_DIR=$(mktemp -d)
TARGET_DIR="$BUILD_DIR/python/lib/python${PYVER}/site-packages"
mkdir -p "$TARGET_DIR"

echo "Installing packages into $TARGET_DIR ..."
# Use pip to install packages into the target directory.
# Use pip3 to be explicit; the environment must have a pip compatible with the
# target python version or use a manylinux wheel build environment.
pip3 install --upgrade --no-cache-dir -t "$TARGET_DIR" $PACKAGES

# Cleanup common cruft to reduce layer size
find "$TARGET_DIR" -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
find "$TARGET_DIR" -name "*.dist-info" -type d -prune -exec rm -rf {} + 2>/dev/null || true

# Create the zip with the required directory layout
pushd "$BUILD_DIR" > /dev/null
zip -r9 "$OUTPUT_ZIP" python > /dev/null
popd > /dev/null

# Move zip to current working directory
mv "$BUILD_DIR/$OUTPUT_ZIP" .

echo "Layer archive created: $OUTPUT_ZIP"

# Cleanup
rm -rf "$BUILD_DIR"

echo "Done. Remember to upload $OUTPUT_ZIP as the layer (terraform expects it at \${path.module}/requests_layer.zip)."
