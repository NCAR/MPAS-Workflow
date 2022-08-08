#!/bin/csh -f

if ( $?config_workflow ) exit 0
setenv config_workflow 1

source config/tools.csh

source config/scenario.csh workflow

$setLocal firstCyclePoint

## FirstCycleDate is formatted for non-cylc parts of the workflow
set yymmdd = `echo ${firstCyclePoint} | cut -c 1-8`
set hh = `echo ${firstCyclePoint} | cut -c 10-11`
setenv FirstCycleDate ${yymmdd}${hh}

$setLocal initialCyclePoint
$setLocal finalCyclePoint

# critical path selection
$setLocal CriticalPathType

# verification
$setLocal VerifyAgainstObservations
$setLocal VerifyAgainstExternalAnalyses
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
$setLocal ExtendedFCLengthHR
$setLocal ExtendedFCOutIntervalHR
$setLocal ExtendedMeanFCTimes
$setLocal ExtendedEnsFCTimes
$setLocal DAVFWindowHR
$setLocal FCVFWindowHR

## next date from which first background is initialized
set nextFirstCycleDate = `$advanceCYMDH ${FirstCycleDate} +${CyclingWindowHR}`
setenv nextFirstCycleDate ${nextFirstCycleDate}
set Nyy = `echo ${nextFirstCycleDate} | cut -c 1-4`
set Nmm = `echo ${nextFirstCycleDate} | cut -c 5-6`
set Ndd = `echo ${nextFirstCycleDate} | cut -c 7-8`
set Nhh = `echo ${nextFirstCycleDate} | cut -c 9-10`
set nextFirstFileDate = ${Nyy}-${Nmm}-${Ndd}_${Nhh}.00.00

# maximum active cycle points
$setLocal maxActiveCyclePoints

## DA2FCOffsetHR and FC2DAOffsetHR: control the offsets between DataAssim and Forecast
# tasks in the critical path
# TODO: set DA2FCOffsetHR and FC2DAOffsetHR based on IAU controls
setenv DA2FCOffsetHR 0
setenv FC2DAOffsetHR ${CyclingWindowHR}
