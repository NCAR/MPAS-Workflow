#!/bin/csh -f

####################################################################################################
# This script runs an automated set of cylc suites that test the MPAS-Workflow. Each of the test
# cases is designed to exercise a unique aspect of the known working functionality.  If the
# user has previously executed this script, and one or more test case suites are already running,
# then executing this script again will cause drive.csh to kill those running suites.
####################################################################################################

## Usage:
#   source env/cheyenne.${YourEnvironment}
#   ./autotestForPR.csh

## testStage
# choose a stage of the workflow to run for the test cases.  It can be useful to run only the
# SetupWorkflow stage in order to check that all scripts run correctly or to re-initialize
# the MPAS-Worlfow config directories of all of the tests.  The latter is useful when a simple
# update to the config directory will enable a workflow task to run, and avoids re-starting
# the one or more cylc suites.  drive.csh automatically stops active test suites when this script
# is executed.
# OPTIONS: drive, SetupWorkflow
set testStage = drive

## test* settings
# these values will be used to run the test suites

## testCaseNames
# list of test cases to run, ordered from most simple to most complex
# If multiple test cases fail, it is advisable to progress by debugging and re-testing with only
# the most simple of the failing cases until it passes in order to reduce computational overhead.
# Then proceed with the remainder of the cases until all complete.
set l = ()
set l = ($l WarmStart_OIE120km_3dvar)
set l = ($l WarmStart_OIE120km_3denvar)
set l = ($l ColdStart_2018041418_OIE120km_3dvar)
set l = ($l WarmStart_O30kmIE60km_3denvar)
set l = ($l WarmStart_OIE120km_eda_3denvar)
set testCaseNames = ($l)

## testExpSuffix
# Controls the ExpSuffix in config/experiment.csh.  If testing for multiple branches or across
# non-yaml-configured settings, it is convenient to modify this suffix here in order to distinguish
# the scenarios.
set testExpSuffix = '_autotestForPR'

## testCPQueueName
# Queue that will be used for critical path jobs.  If time allows, it is best to use economy.
set testCPQueueName = economy

## testFinalCyclePoint
# final cycle date-time for all cases
set testFinalCyclePoint = 20180415T06

## default* settings
# these values will be restored after all test suites are initialized
set defaultCaseName = WarmStart_OIE120km_3dvar
set defaultExpSuffix = ''
set defaultCPQueueName = regular
set defaultFinalCyclePoint = 20180514T18


###################################################################################################
# run the tests (do not modify below this line)
###################################################################################################

sed -i 's@^set\ ExpSuffix\ =\ .*@set\ ExpSuffix\ =\ "'$testExpSuffix'"@' config/experiment.csh
sed -i 's@^setenv\ CPQueueName.*@setenv\ CPQueueName\ '$testCPQueueName'@' config/job.csh
sed -i 's@^set\ finalCyclePoint\ =\ .*@set\ finalCyclePoint\ =\ '$testFinalCyclePoint'@' drive.csh

foreach caseName ($testCaseNames)
  echo ""
  echo ""
  echo "##################################################################"
  echo "${0}: Running test case: $caseName"

  sed -i 's@^set\ caseName\ =\ .*@set\ caseName\ =\ '$caseName'@' config/experiment.csh
  sed -i 's@^set\ SuiteName\ =\ .*@set\ SuiteName\ =\ '$caseName'@' drive.csh
  ./${testStage}.csh

  if ( $status != 0 ) then
    echo "ERROR in $0 : error when setting up $caseName" > ./FAIL
    exit 1
  endif
end

# always return to the default values at the end
sed -i 's@^set\ caseName\ =\ .*@set\ caseName\ =\ '$defaultCaseName'@' config/experiment.csh
sed -i 's@^set\ ExpSuffix\ =\ .*@set\ ExpSuffix\ =\ "'$defaultExpSuffix'"@' config/experiment.csh
sed -i 's@^setenv\ CPQueueName.*@setenv\ CPQueueName\ '$defaultCPQueueName'@' config/job.csh
sed -i 's@^set\ finalCyclePoint\ =\ .*@set\ finalCyclePoint\ =\ '$defaultFinalCyclePoint'@' drive.csh
sed -i 's@^set\ SuiteName\ =\ .*@set\ SuiteName\ =\ ${ExperimentName}@' drive.csh
