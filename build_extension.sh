#!/bin/bash
set -e

# Improved build script for Formix DevTools extension
# Addresses the "could not read file as String" and 404 errors.

EXTENSION_DIR="devtools_extension"
DEST_DIR="extension/devtools"

echo "Building extension in $EXTENSION_DIR..."
cd $EXTENSION_DIR

# Clean extension build dir
rm -rf build

# Get dependencies
flutter pub get

# Build for web with WASM support
echo "Building for web with --wasm..."
# --no-tree-shake-icons to avoid issues with missing icons in the extension
flutter build web --wasm --no-tree-shake-icons

# Go back to root
cd ..

echo "Cleaning and preparing destination $DEST_DIR..."
# 1. Save config.yaml if it exists
if [ -f "$DEST_DIR/config.yaml" ]; then
    cp "$DEST_DIR/config.yaml" /tmp/formix_config.yaml
fi

# 2. Fully clean the destination to remove any stale/0-byte files
rm -rf "$DEST_DIR"
mkdir -p "$DEST_DIR/build"

# 3. Restore config.yaml
if [ -f /tmp/formix_config.yaml ]; then
    mv /tmp/formix_config.yaml "$DEST_DIR/config.yaml"
else
    echo "Creating default config.yaml..."
    cat > "$DEST_DIR/config.yaml" <<EOF
name: formix
version: 0.2.0
issueTracker: https://github.com/Shreemanarjun/formix/issues
materialIconCodePoint: "0xf0c5"
requiresConnection: true
EOF
fi

# 4. Copy the entire build output to the build/ directory (standard)
echo "Copying build output to $DEST_DIR/build..."
cp -r $EXTENSION_DIR/build/web/* $DEST_DIR/build/

# 5. Adjust index.html for relative paths inside DevTools iframes
echo "Adjusting index.html for relative paths..."
sed -i '' 's/<base href="[^"]*">/<base href=".\/">/g' $DEST_DIR/build/index.html
sed -i '' 's/<link rel="manifest" href="manifest.json">//g' $DEST_DIR/build/index.html

# 6. Copy essential files to the root of extension/devtools for compatibility
# Some DevTools environments look here.
echo "Syncing root files for compatibility..."
cp $DEST_DIR/build/index.html $DEST_DIR/
cp $DEST_DIR/build/flutter_bootstrap.js $DEST_DIR/
cp $DEST_DIR/build/main.dart.js $DEST_DIR/
[ -f "$DEST_DIR/build/main.dart.wasm" ] && cp $DEST_DIR/build/main.dart.wasm $DEST_DIR/
[ -f "$DEST_DIR/build/main.dart.mjs" ] && cp $DEST_DIR/build/main.dart.mjs $DEST_DIR/

# 7. Validate
echo "Validating extension..."
cd $EXTENSION_DIR
flutter pub run devtools_extensions validate --package=..
cd ..

echo "Build complete! The extension is now ready."
