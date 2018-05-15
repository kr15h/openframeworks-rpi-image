#!/bin/bash

echo "Hello. This is compile script."

echo "Compiling openFrameworks."
make -j Release -C /home/pi/openFrameworks/libs/openFrameworksCompiled/project

echo "Congratulations! openFrameworks $OF_VERSION has been compiled."
