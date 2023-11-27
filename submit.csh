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
cd ${mainScriptDir}

date

echo "$0 (INFO): checking if a suite with the same name is already running"

set status = `cylc scan -t rich | grep -c "${SuiteName} "`
if ( $status > 0 ) then
  echo "$0 (INFO): a cylc suite named $SuiteName is already running!"
  echo "$0 (INFO): stopping the suite (30 sec.), then starting a new one..."
  cylc stop --kill MPAS-Workflow/$SuiteName
  sleep 30
else
  echo "$0 (INFO): confirmed that a cylc suite named $SuiteName is not already running"
  echo "$0 (INFO): starting a new suite..."
endif

if ( -e ${cylcWorkDir}/${SuiteName} ) then
   rm -rf ${cylcWorkDir}/${SuiteName}   
endif

echo "$0 (INFO): register, validate, and run the suite"
echo "$0 (INFO): cylc-flow install suite ${SuiteName}"
cylc install --run-name=${SuiteName}

echo "$0 (INFO): cylc-flow validate suite ${SuiteName}"
cylc validate MPAS-Workflow/${SuiteName}

echo "$0 (INFO): cylc-flow starts running suite ${SuiteName}"
cylc play MPAS-Workflow/${SuiteName}

cd -

exit 0
