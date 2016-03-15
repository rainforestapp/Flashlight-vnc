#!/bin/bash

set -ue

cd $HOME

if [ ! -d flex/apache-flex-sdk-4.14.1-bin ]; then
  mkdir flex
  echo "Getting flex"
  CLOSEST=$(curl -s "http://www.apache.org/dyn/closer.lua/flex/4.14.1/binaries/apache-flex-sdk-4.14.1-bin.tar.gz?as_json=1" | jq -r '.preferred + .path_info')
  curl -s $CLOSEST | tar zxf - -C flex

  (
    cd flex/apache-flex-sdk-4.14.1-bin/frameworks
    ant thirdparty-downloads -Dfont.donot.ask=true:
  )
else
  echo "We have flex, skipping..."
fi

if [ ! -d flex/AIRSDK ]; then
  echo "Getting AIR SDK"
  wget http://airdownload.adobe.com/air/win/download/latest/AdobeAIRSDK.zip
  unzip -d flex/AIRSDK AdobeAIRSDK.zip
else
  echo "We have AIR SDK, skipping..."
fi

# Historic versions:
#   https://github.com/nexussays/playerglobal
#   https://www.adobe.com/support/flashplayer/debug_downloads.html
if [ ! -e flex/player/11.1/playerglobal.swc ]; then
  echo "Getting playerglobal"
  mkdir -p flex/player/11.1
  curl -s https://fpdownload.macromedia.com/get/flashplayer/updaters/18/playerglobal18_0.swc -o flex/player/11.1/playerglobal.swc
else
  echo "We have playerglobal, skipping..."
fi
