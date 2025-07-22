#!/bin/bash
set -e

SOURCE_DIR_NAME="vyos-nextdns"
BUILD_ROOT=$(mktemp -d -p ~)
echo "Using temporary build directory: $BUILD_ROOT"
echo "Copying source to build directory..."
cp -r "." "$BUILD_ROOT/$SOURCE_DIR_NAME"
BUILD_DIR="$BUILD_ROOT/$SOURCE_DIR_NAME"

echo "Restructuring package layout..."
# Move contents of src/ to the root of BUILD_DIR for proper Debian package structure
if [ -d "$BUILD_DIR/src" ]; then
    cp -r "$BUILD_DIR/src/"* "$BUILD_DIR/"
    rm -rf "$BUILD_DIR/src"
fi

echo "Converting script line endings to Unix format..."
find "$BUILD_DIR" -type f \( -name "*.sh" -o -name "*.py" -o -name "postinst" -o -name "postrm" -o -name "prerm" \) -exec sed -i 's/\r$//' {} +

echo "Setting package permissions in build directory..."
# Set executable permissions for scripts
chmod 0755 "$BUILD_DIR/DEBIAN/postinst"
chmod 0755 "$BUILD_DIR/DEBIAN/postrm"
chmod 0755 "$BUILD_DIR/DEBIAN/prerm"
chmod +x "$BUILD_DIR/config/nextdns/start_nextdns.sh"
chmod +x "$BUILD_DIR/config/nextdns/generate_nodes.sh"
chmod +x "$BUILD_DIR/config/nextdns/service_nextdns.py"
# Set proper permissions for service file
chmod 0644 "$BUILD_DIR/config/nextdns/nextdns.service"

echo "Building Debian package..."
dpkg-deb --build "$BUILD_DIR"

# Extract version to construct the new package name
VERSION=$(grep -oP 'Version: \K.*' "$BUILD_DIR/DEBIAN/control" | tr -d '\r')
NEW_PACKAGE_NAME="nextdns_${VERSION}_vyos.deb"

echo "Moving and renaming package to: $NEW_PACKAGE_NAME"
mv "$BUILD_ROOT/$SOURCE_DIR_NAME.deb" "./$NEW_PACKAGE_NAME"

echo "Cleaning up..."
rm -rf "$BUILD_ROOT"

echo "Package built successfully: ./$NEW_PACKAGE_NAME"
