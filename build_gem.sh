#!/bin/bash

cd pkg

echo "cleaning the build directory..."
ls -l *.gem > /dev/null && rm -v *.gem
echo ""

echo "building the new gem..."
rake gem
echo ""

echo "uninstalling the old gem if necessary..."
gem list | grep -c rhcp_shell > /dev/null && sudo gem uninstall rhcp_shell
echo ""

echo "installing the new one..."
sudo gem install --no-rdoc --no-ri *.gem
echo ""

cd -
