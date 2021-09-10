#!/bin/bash
#
# Logics:
#
# if mpas_bundle exist,  do not git clone
# then build from scratch
# 

ecbuild_option="--build=RelWithDebInfo"
bundle_vers="release/mpas-1.0"

if [[ ! -d mpas-bundle ]]; then
    echo " ! -d mpas-bundle "
    git clone -b $bundle_vers  https://github.com/JCSDA-internal/mpas-bundle.git
fi

source ~/.zshenv
[[ -d build ]] && mv -f build  build_$(date '+%Y-%m-%d_%H.%M.%S')
mkdir -p build

cd build
ecbuild  $ecbuild_option  ../mpas-bundle  &> za
make -j12 &> zb
cd mpas-jedi
ctest
