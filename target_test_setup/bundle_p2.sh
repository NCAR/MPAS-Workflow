#!/bin/bash

name_jedi_dir="mpasbundletest"
[[ $# -ge 1 ]] && echo $1 && name_jedi_dir=$1   # override dirname, optional

# Customize variables
AUTOTEST_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
user="yonggangyu"
email=$user@ucar.edu
REL_DIR=$HOME/$name_jedi_dir
CODE_DIR=code    # Changing this will require changes to the automated cycling scripts.
BUILD_DIR=build  # Changing this will require changes to the automated cycling scripts.
echo "src_build_run_dir =$REL_DIR"

# Default email subject and body variables
status=FAILURE
body='Unexpected failure of mpas-bundle autotest script.'

# git and ecbuild were done in bundle_p1.sh

# cmake and ctest
#source $REL_DIR/$CODE_DIR/mpas-bundle/env-setup/gnu-openmpi-mac.sh
source $REL_DIR/$CODE_DIR/mpas-bundle/env-setup/clang-mpich-mac.sh
mkdir -p $REL_DIR/$BUILD_DIR
cd $REL_DIR/$BUILD_DIR
make -j16

# Check if build was successful by checking for presence of final built executable
if [[ -f "$REL_DIR/$BUILD_DIR/bin/mpasjedi_variational.x" ]]; then
   # Build successful. Run ctests.
   cd $REL_DIR/$BUILD_DIR/mpasjedi
   ctest
   # Check if all ctests pass by checking for presence of LastTestsFailed.log
   if [[ -f ./Testing/Temporary/LastTestsFailed.log ]]; then
      body="At least one ctest has failed. See $REL_DIR/$BUILD_DIR/mpasjedi/Testing/Temporary/LastTestsFailed.log"
   elif [[ ! -f ./Testing/Temporary/LastTest.log ]]; then
      body="Build was successful, but no LastTest.log file found. ctests probably did not run for some reason."
   else
      body="mpas-bundle successfully built and all mpas-jedi ctests passed. All is right in the world."
      status=success
      cd $REL_DIR
      cp ${AUTOTEST_DIR}/archive_build.sh ./
      ./archive_build.sh
   fi
else
   body="mpas-bundle failed to build. See build logs in $REL_DIR or ${AUTOTEST_DIR}"
fi
# Notify $email about what happened.
#mail -s "mpas-bundle cron autotest $status" $email <<< "$body" 
