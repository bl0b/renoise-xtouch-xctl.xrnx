#!/bin/bash

rm -rf build_dir
mkdir build_dir
cd build_dir

#git clone git@github.com:bl0b/renoise-xtouch-xctl.xrnx.git .
git clone .. .

mv manifest.xml.release manifest.xml

VERSION=`grep '<Version' manifest.xml | sed 's/.*>\(.*\)<.*/\1/'`

zip -r ../dev.bl0b.X-Touch_$VERSION.xrnx *
cd ..
rm -rf build_dir
