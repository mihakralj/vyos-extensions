#!/bin/bash
set -e

BUILD_DIR="/tmp/build_area"
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
SOURCE_DIR="$SCRIPT_DIR/src"

echo "Preparing build directory: $BUILD_DIR"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cp -r "$SOURCE_DIR"/* "$BUILD_DIR"/

echo "Building in: $BUILD_DIR"

echo "Converting script line endings to Unix format..."
find "$BUILD_DIR" -type f \( -name "*.sh" -o -name "*.py" -o -name "postinst" -o -name "postrm" -o -name "prerm" \) -exec sed -i 's/\r$//' {} +

echo "Setting package permissions..."
chmod 0755 "$BUILD_DIR/DEBIAN/postinst"
chmod 0755 "$BUILD_DIR/DEBIAN/postrm"
chmod 0755 "$BUILD_DIR/DEBIAN/prerm"
chmod +x "$BUILD_DIR/config/tailscale/start_tailscale.sh"
chmod +x "$BUILD_DIR/config/tailscale/generate_nodes.sh"
chmod +x "$BUILD_DIR/config/tailscale/service_tailscale.py"
chmod 0644 "$BUILD_DIR/config/tailscale/tailscaled.service"

echo "Building Debian package..."
dpkg-deb --build "$BUILD_DIR" /tmp/

PACKAGE_NAME=$(grep -oP 'Package: \K.*' "$BUILD_DIR/DEBIAN/control" | tr -d '\r')
VERSION=$(grep -oP 'Version: \K.*' "$BUILD_DIR/DEBIAN/control" | tr -d '\r')
ARCH=$(grep -oP 'Architecture: \K.*' "$BUILD_DIR/DEBIAN/control" | tr -d '\r')

ORIGINAL_PACKAGE_NAME="${PACKAGE_NAME}_${VERSION}_${ARCH}.deb"
NEW_PACKAGE_NAME="tailscale_${VERSION}_vyos.deb"

echo "Moving and renaming package to: $SCRIPT_DIR/$NEW_PACKAGE_NAME"
mv "/tmp/$ORIGINAL_PACKAGE_NAME" "$SCRIPT_DIR/$NEW_PACKAGE_NAME"

echo "Cleaning up..."
rm -rf "$BUILD_DIR"

echo "Package built successfully: $SCRIPT_DIR/$NEW_PACKAGE_NAME"
