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

#module purge
#module load cylc
#module load graphviz
module load conda/latest
conda activate cylc8

date

echo "$0 (INFO): checking if a suite with the same name is already running"

#cylc poll $SuiteName >& /dev/null
#if ( $status == 0 ) then
#  echo "$0 (INFO): a cylc suite named $SuiteName is already running!"
#  echo "$0 (INFO): stopping the suite (30 sec.), then starting a new one..."
#  cylc stop --kill $SuiteName
#  sleep 30
#else
#  echo "$0 (INFO): confirmed that a cylc suite named $SuiteName is not already running"
#  echo "$0 (INFO): starting a new suite..."
#endif
cylc stop --kill MPAS-Workflow/$SuiteName
#sleep 30

rm -rf ${cylcWorkDir}/${SuiteName}

echo "$0 (INFO): register, validate, and run the suite"
#cylc register ${SuiteName} ${mainScriptDir}
#cylc validate --strict ${SuiteName}
#cylc run ${SuiteName}
if ( -e ~/cylc-run/MPAS-Workflow/${SuiteName} ) then
  rm -r ~/cylc-run/MPAS-Workflow/${SuiteName}
  echo "Already has this suite, replay it"
endif
echo "cylc-flow install suite ${SuiteName}"
cylc install --run-name=${SuiteName}

echo "cylc-flow validate suite ${SuiteName}"
cylc validate MPAS-Workflow/${SuiteName}

echo "cylc-flow strats running suite ${SuiteName}"
cylc play MPAS-Workflow/${SuiteName}

cd -

exit 0
