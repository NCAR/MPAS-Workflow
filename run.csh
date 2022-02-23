#!/bin/csh -f

source config/environmentPython.csh

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
  PullRequest \
  OneMonth120km3dvar \
  OneMonth120km3denvar \
  OneMonth30km-60km3denvar \
)
set ArgRunConfig = $1

if ( "$ValidRunConfigs" =~ *"$ArgRunConfig"* ) then
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
set defaults = runs/defaults.yaml

# this config
set runConfig = runs/${ArgRunConfig}.yaml

# getRun, setRun, and setRestore are helper functions that pick out individual
# configuration elements from within the "run"  and "restore" keys of runConfig
set getRun = "$getConfig $defaults $runConfig run"
setenv setRun "source $setConfig $defaults $runConfig run"
setenv setRestore "source $setConfig $defaults $runConfig restore"


# these values will be used during the run phase
# see runs/defaults.yaml for configuration documentation
set scenarios = (`$getRun scenarios`)
$setRun ExpSuffix
$setRun CPQueueName
$setRun initialCyclePoint
$setRun finalCyclePoint
#TODO: enable FirstCycleDate setting
#$setRun FirstCycleDate

###################################################################################################
# run the scenarios (only developers should modify this)
###################################################################################################

sed -i 's@^set\ ExpSuffix\ =\ .*@set\ ExpSuffix\ =\ "'$ExpSuffix'"@' config/experiment.csh
sed -i 's@^setenv\ CPQueueName.*@setenv\ CPQueueName\ '$CPQueueName'@' config/job.csh
sed -i 's@^set\ initialCyclePoint\ =\ .*@set\ initialCyclePoint\ =\ '$initialCyclePoint'@' drive.csh
sed -i 's@^set\ finalCyclePoint\ =\ .*@set\ finalCyclePoint\ =\ '$finalCyclePoint'@' drive.csh

foreach thisScenario ($scenarios)
  echo ""
  echo ""
  echo "##################################################################"
  echo "${0}: Running scenario: $thisScenario"

  sed -i 's@^set\ scenario\ =\ .*@set\ scenario\ =\ '$thisScenario'@' config/experiment.csh
  sed -i 's@^set\ SuiteName\ =\ .*@set\ SuiteName\ =\ '$thisScenario'@' drive.csh
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
$setRestore scenario
$setRestore ExpSuffix
$setRestore CPQueueName
$setRestore initialCyclePoint
$setRestore finalCyclePoint
#TODO: enable FirstCycleDate setting
#$setRestore FirstCycleDate

sed -i 's@^set\ scenario\ =\ .*@set\ scenario\ =\ '$scenario'@' config/experiment.csh
sed -i 's@^set\ SuiteName\ =\ .*@set\ SuiteName\ =\ ${ExperimentName}@' drive.csh

sed -i 's@^set\ ExpSuffix\ =\ .*@set\ ExpSuffix\ =\ "'$ExpSuffix'"@' config/experiment.csh

sed -i 's@^setenv\ CPQueueName.*@setenv\ CPQueueName\ '$CPQueueName'@' config/job.csh

sed -i 's@^set\ initialCyclePoint\ =\ .*@set\ initialCyclePoint\ =\ '$initialCyclePoint'@' drive.csh
sed -i 's@^set\ finalCyclePoint\ =\ .*@set\ finalCyclePoint\ =\ '$finalCyclePoint'@' drive.csh
