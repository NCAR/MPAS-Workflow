#!/bin/csh

# (C) Copyright 2023 UCAR
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

####################################################################################################
# This script runs a pre-generated cylc suite.rc file in the local directory. If the user
# has previously executed this script with the same "SuiteName", and the scenario is already
# running, then executing this script will automatically kill that running suite.
####################################################################################################

echo "$0 (INFO): Generating the scenario-specific MPAS-Workflow directory"

# Create/copy the task shell scripts

# experiment provides mainScriptDir, SuiteName
source config/auto/experiment.csh

## Change to the cylc suite directory
echo $0 cd ${mainScriptDir}
cd ${mainScriptDir}

set NCARHOST=$NCAR_HOST
if ( "$NCARHOST" == "derecho" ) then
  if ( ! $?CYLC_ENV ) then
    echo "CYLC_ENV environment variable must be set to the name of the conda cylc8 package"
    exit
  endif

  echo $0 conda activate $CYLC_ENV
  conda activate $CYLC_ENV
  #set cylc_timeout="--comms-timeout=10"
else if ( "$NCARHOST" == "cheyenne" ) then
  module purge
  echo $0 module load cylc
  module load cylc
  module load graphviz
else
  echo "unknown NCARHOST:" $NCARHOST
  exit 1
endif

echo $0 cylc version: `cylc --version`
date

echo "$0 (INFO): checking if a suite with the same name is already running"

if ( "$NCARHOST" == "derecho" ) then
  echo "$0 (INFO): stopping the suite (30 sec.), then starting a new one..."
  echo $0 cylc stop --kill MPAS-Workflow/$SuiteName
  cylc stop --kill MPAS-Workflow/$SuiteName
  sleep 5
  echo $0 cylc scan -t rich
  cylc scan -t rich
else if ( "$NCARHOST" == "cheyenne" ) then
  echo $0 cylc poll $SuiteName 
  cylc poll $SuiteName 
  if ( $status == 0 ) then
    echo "$0 (INFO): a cylc suite named $SuiteName is already running!"
    echo "$0 (INFO): stopping the suite (30 sec.), then starting a new one..."
    cylc stop --kill $SuiteName
    sleep 30
  else
    echo "$0 (INFO): confirmed that a cylc suite named $SuiteName is not already running"
    echo "$0 (INFO): starting a new suite..."
  endif
endif

echo $0 cylcWorkDir  ${cylcWorkDir}
echo $0 SuiteName ${SuiteName}
echo $0 mainScriptDir ${mainScriptDir}
rm -rf ${cylcWorkDir}/${SuiteName}

if ( "$NCARHOST" == "derecho" ) then
  if ( -e ~/cylc-run/MPAS-Workflow/${SuiteName} ) then
    echo $0 rm -r ~/cylc-run/MPAS-Workflow/${SuiteName}
    rm -r ~/cylc-run/MPAS-Workflow/${SuiteName}
  #  echo "Already has this suite, replay it"
  endif
  echo $0 cylc install --run-name=${SuiteName}
  cylc install --run-name=${SuiteName}
  echo $0  cylc validate MPAS-Workflow/${SuiteName}
  cylc validate MPAS-Workflow/${SuiteName}
  echo $0 cylc play MPAS-Workflow/${SuiteName}
  cylc play MPAS-Workflow/${SuiteName}
else if ( "$NCARHOST" == "cheyenne" ) then
  echo "$0 (INFO): register, validate, and run the suite:", ${SuiteName}
  echo $0 cylc register ${SuiteName} ${mainScriptDir}
  cylc register ${SuiteName} ${mainScriptDir}
  echo $0  cylc validate --strict ${SuiteName}
  cylc validate --strict ${SuiteName}
  echo $0 cylc run ${SuiteName}
  cylc run ${SuiteName}
endif

cd -

exit 0
