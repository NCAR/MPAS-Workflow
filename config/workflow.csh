#!/bin/csh -f

if ( $?config_workflow ) exit 0
setenv config_workflow 1

source config/scenario.csh workflow setNestedWorkflow

$setLocal firstCyclePoint

## FirstCycleDate is formatted for non-cylc parts of the workflow
set yymmdd = `echo ${firstCyclePoint} | cut -c 1-8`
set hh = `echo ${firstCyclePoint} | cut -c 10-11`
setenv FirstCycleDate ${yymmdd}${hh}

$setLocal initialCyclePoint
$setLocal finalCyclePoint

# cold (online) vs. warm (offline)
$setLocal InitializationType

# critical path selection
$setLocal CriticalPathType

# verification
$setLocal VerifyDeterministicDA
$setLocal CompareDA2Benchmark
$setLocal VerifyExtendedMeanFC
$setLocal VerifyBGMembers
$setLocal CompareBG2Benchmark
$setLocal VerifyEnsMeanBG
$setLocal DiagnoseEnsSpreadBG
$setLocal VerifyANMembers
$setLocal VerifyExtendedEnsFC

# durations and intervals
$setLocal CyclingWindowHR
$setLocal ExtendedFCWindowHR
$setLocal ExtendedFC_DT_HR
$setLocal ExtendedMeanFCTimes
$setLocal ExtendedEnsFCTimes
$setLocal DAVFWindowHR
$setLocal FCVFWindowHR

# maximum active cycle points
$setLocal maxActiveCyclePoints

## DA2FCOffsetHR and FC2DAOffsetHR: control the offsets between DataAssim and Forecast
# tasks in the critical path
# TODO: set DA2FCOffsetHR and FC2DAOffsetHR based on IAU controls
setenv DA2FCOffsetHR 0
setenv FC2DAOffsetHR ${CyclingWindowHR}
