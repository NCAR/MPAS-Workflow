#!/bin/bash

name_jedi_dir="mpasbundletest"
[[ $# -ge 1 ]] && echo $1 && name_jedi_dir=$1   # override dirname, optional

# Customize variables
AUTOTEST_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
user="yonggangyu"
email=$user@ucar.edu
REL_DIR=$HOME/$name_jedi_dir
CODE_DIR=code        # permanent 
BUILD_DIR=build      # per..
echo "src_build_run_dir =$REL_DIR"
bundle_branch="feature/mac_test"
ecbuild_option="--build=RelWithDebInfo -DOPENSSL_ROOT_DIR=/usr/local/opt/openssl"

# Default email subject and body variables
status=FAILURE
body='Unexpected failure of mpas-bundle autotest script.'

[[ -d $REL_DIR/$CODE_DIR  ]] && \
   mv -f $REL_DIR/$CODE_DIR  $REL_DIR/${CODE_DIR}_$(date '+%Y-%m-%d_%H.%M.%S')

[[ -d $REL_DIR/$BUILD_DIR ]] && \
   mv -f $REL_DIR/$BUILD_DIR $REL_DIR/${BUILD_DIR}_$(date '+%Y-%m-%d_%H.%M.%S')


mkdir -p $REL_DIR/$CODE_DIR
cd $REL_DIR/$CODE_DIR
git clone -b ${bundle_branch} git@github.com:JCSDA-internal/mpas-bundle.git
sed -i_HTTP 's/https:\/\/github.com\//git@github.com:/' mpas-bundle/CMakeLists.txt
source $REL_DIR/$CODE_DIR/mpas-bundle/env-setup/clang-mpich-mac.sh

mkdir -p $REL_DIR/$BUILD_DIR
cd $REL_DIR/$BUILD_DIR
ecbuild  $ecbuild_option  $REL_DIR/$CODE_DIR/mpas-bundle

# end before make -j16; ctest
