#!/bin/bash

name_jedi_dir="mpasbundletest"
[[ $# -ge 1 ]] && echo $1 && name_jedi_dir=$1   # override dirname, optional

# Customize variables
AUTOTEST_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
user=${USER}
email=$user@ucar.edu
REL_DIR=/glade/scratch/$user/$name_jedi_dir
CODE_DIR=code    # Changing this will require changes to the automated cycling scripts.
BUILD_DIR=build  # Changing this will require changes to the automated cycling scripts.
echo "src_build_run_dir =$REL_DIR"
bunle_branch="debug/test_ver_June25"     # default "develop"
ecbuild_option="--build=RelWithDebInfo"
# ecbuild_option="--build=RelWithDebInfo -DBUNDLE_SKIP_ECKIT=OFF  -DBUNDLE_SKIP_FCKIT=OFF  -DBUNDLE_SKIP_ATLAS=OFF"

# Default email subject and body variables
status=FAILURE
body='Unexpected failure of mpas-bundle autotest script.'


[[ -d $REL_DIR/$CODE_DIR  ]] && \
   mv -f $REL_DIR/$CODE_DIR  $REL_DIR/${CODE_DIR}$(date +"%Y%m%d%h%s")
mkdir -p $REL_DIR/$CODE_DIR
cd $REL_DIR/$CODE_DIR
git clone -b ${bunle_branch} git@github.com:JCSDA-internal/mpas-bundle.git
sed -i_HTTP 's/https:\/\/github.com\//git@github.com:/' mpas-bundle/CMakeLists.txt
source $REL_DIR/$CODE_DIR/mpas-bundle/env-setup/gnu-openmpi-cheyenne.sh


[[ -d $REL_DIR/$BUILD_DIR ]] && \
   mv -f $REL_DIR/$BUILD_DIR $REL_DIR/${BUILD_DIR}_$(date +"%Y%m%d%h%s")
mkdir -p $REL_DIR/$BUILD_DIR
cd $REL_DIR/$BUILD_DIR
ecbuild  $ecbuild_option  $REL_DIR/$CODE_DIR/mpas-bundle


# end before make -j8; ctest
