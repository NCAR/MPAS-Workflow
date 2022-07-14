#!/bin/csh -f

####################################################################################################
# This script runs a pre-configured set of cylc suites via MPAS-Workflow. If the user has
# previously executed this script with the same "ArgRunConfig", and one or more of the scenarios is
# already running, then executing this script again will cause drive.csh to kill those running
# suites.
####################################################################################################

## Usage:
#   source env/cheyenne.${YourShell}
#   ./run.csh {{runConfig}}

## ArgRunConfig
# A YAML file describing the set of scenarios to run
# OPTIONS:
set ValidRunConfigs = ( \
  test \
  120km3dvar \
  120km3denvar \
  120kmEDA \
  60kmEDA \
  30km-60km3denvar \
  30km-60km3denvarSpecifiedEnsemble \
  RealTime \
  GenerateObs \
  GenerateGFSAnalyses \
  ForecastFromGFSAnalyses \
  IASI120km3denvar \
)
set ArgRunConfig = $1

if ("$ValidRunConfigs" =~ *"$ArgRunConfig"* && $ArgRunConfig != '') then
  echo "$0 (INFO): Running the $ArgRunConfig set of scenarios"
else
  echo "$0 (ERROR): invalid ArgRunConfig, $ArgRunConfig"
  exit 1
endif

## stage
# Choose which stage of the workflow to run for all scenarios.  It can be useful to run only the
# SetupWorkflow stage in order to check that all scripts run correctly or to re-initialize
# the MPAS-Worlfow config directories of all of the scenarios.  The latter is useful when a simple
# update to the config directory will enable a workflow task to run, and avoids re-starting
# the one or more cylc suites.  drive.csh automatically stops active scenario suites when the user
# executes this script script.
# OPTIONS: drive, SetupWorkflow
set stage = drive

###################################################################################################
# get the configuration (only developers should modify this)
###################################################################################################

# config tools
source config/config.csh

# defaults config
set baseConfig = runs/base.yaml

# this config
set runConfig = runs/${ArgRunConfig}.yaml

# setRun and setRestore are helper functions that pick out a configuration node
# under the "run" and "restore" keys of runConfig
setenv setRun "source $setConfig $baseConfig $runConfig run"
setenv setRestore "source $setConfig $baseConfig $runConfig restore"

# these values will be used during the run phase
# see runs/baseConfig.yaml for configuration documentation
$setRun scenarios
$setRun scenarioDirectory

###################################################################################################
# run the scenarios (only developers should modify this)
###################################################################################################

sed -i 's@^set\ scenarioDirectory\ =\ .*@set\ scenarioDirectory\ =\ '$scenarioDirectory'@' config/scenario.csh

foreach thisScenario ($scenarios)
  if ($thisScenario == None) then
    continue
  endif
  echo ""
  echo ""
  echo "##################################################################"
  echo "${0}: Executing ${stage}.csh for the $thisScenario scenario"
  sed -i 's@^set\ scenario\ =\ .*@set\ scenario\ =\ '$thisScenario'@' config/scenario.csh
  ./${stage}.csh

  if ( $status != 0 ) then
    echo "$0 (ERROR): error when setting up $thisScenario"
    exit 1
  endif
end

###################################################################################################
# restore settings (only developers should modify this)
###################################################################################################

## restore* settings
# these values are restored now that all suites are initialized
$setRestore scenarioDirectory
sed -i 's@^set\ scenarioDirectory\ =\ .*@set\ scenarioDirectory\ =\ '$scenarioDirectory'@' config/scenario.csh
$setRestore scenario
sed -i 's@^set\ scenario\ =\ .*@set\ scenario\ =\ '$scenario'@' config/scenario.csh
