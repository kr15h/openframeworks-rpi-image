#!/bin/bash

echo "Start of image-compile-script.sh"

echo "Compiling openFrameworks..."
timeout 30m make -j $(nproc) Release -C /home/pi/openFrameworks/libs/openFrameworksCompiled/project

echo "End of image-compile-script.sh"
