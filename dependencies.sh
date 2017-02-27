#!/bin/bash

set -ue

cd "$HOME"

if [ ! -d "flex" ]; then
  curl -s http://vcontrol-images.s3-website.eu-central-1.amazonaws.com/raw/flashlight-dependencies.tar.gz | tar zxf -
else
  echo "We have flex, skipping..."
fi
