#!/bin/bash

echo ""

CCB_VERSION=$1
XCCONFIG="SpriteBuilder.xcconfig"
PRODUCT_NAME=SpriteBuilder

if [ "$#" -ne 1 ]; then
    echo "uasge: ./BuildDistribution.sh <version eg:0.9>"
    echo "eg  ./BuildDistribution.sh 0.9"
    exit 1
fi


# Change to the script's working directory no matter from where the script was called (except if there are symlinks used)
# Solution from: http://stackoverflow.com/questions/59895/can-a-bash-script-tell-what-directory-its-stored-in
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo Script working directory: $SCRIPT_DIR
cd "$SCRIPT_DIR"

# Remove build directory
cd ..
CCB_DIR=$(pwd)

rm -Rf build/
rm -Rf SpriteBuilder/build/

sh ./scripts/CreateAllGeneratedFiles.sh $CCB_VERSION


# Clean and build CocosBuilder
echo "=== CLEANING PROJECT ==="

cd SpriteBuilder/
xcodebuild -alltargets clean | egrep -A 5 "(error):|(SUCCEEDED \*\*)|(FAILED \*\*)"

echo "=== BUILDING SPRITEBUILDER === (please be patient)"


#| egrep -A 5 "(error):|(SUCCEEDED \*\*)|(FAILED \*\*)"
xcodebuild -target SpriteBuilder -configuration Release -xcconfig $XCCONFIG build 


# Create archives
echo "=== ZIPPING UP FILES ==="

cd ..
mkdir build
pwd
cp -R SpriteBuilder/build/Release/$PRODUCT_NAME.app build/$PRODUCT_NAME.app
cp -R SpriteBuilder/build/Release/$PRODUCT_NAME.app.dSYM build/$PRODUCT_NAME.app.dSYM

cd build/
zip -q -r "$PRODUCT_NAME.app.dSYM.zip" $PRODUCT_NAME.app.dSYM

echo ""
echo "$PRODUCT_NAME Distribution Build complete!"
echo "You can now open $PRODUCT_NAME/$PRODUCT_NAME.xcodeproj"