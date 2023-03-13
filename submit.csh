#!/bin/csh

####################################################################################################
# This script runs a pre-configure cylc suite scenario described in config/scenario.csh. If the user
# has previously executed this script with the same effecitve "SuiteName" the scenario is
# already running, then executing this script will automatically kill those running suites.
####################################################################################################

echo "$0 (INFO): Generating the scenario-specific MPAS-Workflow directory"

# Create/copy the task shell scripts

# experiment provides mainScriptDir
source config/auto/experiment.csh

set configParts = ( \
  bin \
  config \
  include \
  scenarios \
  suites \
  test \
  tools \
)
foreach part ($configParts)
  cp -rP $part ${mainScriptDir}/
end

## Change to the cylc suite directory
cd ${mainScriptDir}

module purge
module load cylc
module load graphviz

date

# copy suite to cylc-recognized location
cp -v suites/auto/suite.rc ./

echo "$0 (INFO): checking if a suite with the same name is already running"

cylc poll $SuiteName >& /dev/null
if ( $status == 0 ) then
  echo "$0 (INFO): a cylc suite named $SuiteName is already running!"
  echo "$0 (INFO): stopping the suite (30 sec.), then starting a new one..."
  cylc stop --kill $SuiteName
  sleep 30
else
  echo "$0 (INFO): confirmed that a cylc suite named $SuiteName is not already running"
  echo "$0 (INFO): starting a new suite..."
endif

rm -rf ${cylcWorkDir}/${SuiteName}

echo "$0 (INFO): register, validate, and run the suite"
cylc register ${SuiteName} ${mainScriptDir}
cylc validate --strict ${SuiteName}
cylc run ${SuiteName}

cd -

exit 0