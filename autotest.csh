#!/bin/csh -f

## test* settings
# these values will be used to run the test suites
set l = ()
set l = ($l WarmStart_OIE120km_3dvar)
set l = ($l WarmStart_OIE120km_3denvar)
set l = ($l WarmStart_OIE120km_eda_3denvar)
set l = ($l ColdStart_2018041418_OIE120km_3dvar)
set l = ($l WarmStart_O30kmIE60km_3denvar)
set testCaseNames = ($l)

set testExpSuffix = '_'
set testCPQueueName = economy
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
  ./drive.csh
end

# always return to the default values at the end
sed -i 's@^set\ caseName\ =\ .*@set\ caseName\ =\ '$defaultCaseName'@' config/experiment.csh
sed -i 's@^set\ ExpSuffix\ =\ .*@set\ ExpSuffix\ =\ "'$defaultExpSuffix'"@' config/experiment.csh
sed -i 's@^setenv\ CPQueueName.*@setenv\ CPQueueName\ '$defaultCPQueueName'@' config/job.csh
sed -i 's@^set\ finalCyclePoint\ =\ .*@set\ finalCyclePoint\ =\ '$defaultFinalCyclePoint'@' drive.csh
