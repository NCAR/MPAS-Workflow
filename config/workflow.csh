#!/bin/csh -f

if ( $?config_workflow ) exit 0
setenv config_workflow 1

source config/config.csh
source config/environmentPython.csh
source config/scenario.csh

# getWorkflow and setWorkflow are helper functions that pick out individual
# configuration elements from within the "workflow" key of the scenario configuration
setenv getWorkflow "$getConfig $defaults $scenarioConfig workflow"
setenv setWorkflow "source $setConfig $defaults $scenarioConfig workflow"

$setWorkflow firstCyclePoint
$setWorkflow initialCyclePoint
$setWorkflow finalCyclePoint
$setWorkflow InitializationType
$setWorkflow PreprocessObs
$setWorkflow CriticalPathType
$setWorkflow VerifyDeterministicDA
$setWorkflow CompareDA2Benchmark
$setWorkflow VerifyExtendedMeanFC
$setWorkflow VerifyBGMembers
$setWorkflow CompareBG2Benchmark
$setWorkflow VerifyEnsMeanBG
$setWorkflow DiagnoseEnsSpreadBG
$setWorkflow VerifyANMembers
$setWorkflow VerifyExtendedEnsFC
