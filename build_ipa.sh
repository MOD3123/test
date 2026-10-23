#!/bin/bash
# Lokálny build na Macu (Xcode 14.1+ a XcodeGen: brew install xcodegen)
set -e
cd "$(dirname "$0")"
xcodegen generate
xcodebuild -project WebCenter.xcodeproj -scheme WebCenter \
  -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" build
rm -rf Payload WebCenter.ipa
mkdir Payload
cp -R build/Build/Products/Release-iphoneos/WebCenter.app Payload/
zip -qry WebCenter.ipa Payload
echo "Hotovo: $(pwd)/WebCenter.ipa"
