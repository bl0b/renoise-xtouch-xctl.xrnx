#!/bin/sh

rm -rf build_dir
mkdir build_dir
cd build_dir
git clone git@github.com:bl0b/renoise-xtouch-xctl.xrnx.git .
zip -r ../dev.bl0b.X-Touch.xrnx *
cd ..
rm -rf build_dir
