#!/bin/csh -f

## testStage
# choose a stage of the workflow to run for the test cases.  It can be useful to run only the
# SetupWorkflow stage in order to check that all scripts run correctly or to re-initialize
# the MPAS-Worlfow config directories of all of the tests. The latter use useful when a simple
# update to the config directory will enable a workflow task to run, and avoids re-starting
# the entire workflow.
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
set testExpSuffix = '_autotest-PR'

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
  ./${testStage}.csh
end

# always return to the default values at the end
sed -i 's@^set\ caseName\ =\ .*@set\ caseName\ =\ '$defaultCaseName'@' config/experiment.csh
sed -i 's@^set\ ExpSuffix\ =\ .*@set\ ExpSuffix\ =\ "'$defaultExpSuffix'"@' config/experiment.csh
sed -i 's@^setenv\ CPQueueName.*@setenv\ CPQueueName\ '$defaultCPQueueName'@' config/job.csh
sed -i 's@^set\ finalCyclePoint\ =\ .*@set\ finalCyclePoint\ =\ '$defaultFinalCyclePoint'@' drive.csh
