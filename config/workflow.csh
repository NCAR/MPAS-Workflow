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

# maximum active cycle points
$setLocal maxActiveCyclePoints

# durations and intervals
$setLocal CyclingWindowHR
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

## DA2FCOffsetHR and FC2DAOffsetHR: control the offsets between DataAssim and Forecast
# tasks in the critical path
# TODO: set DA2FCOffsetHR and FC2DAOffsetHR based on IAU controls
setenv DA2FCOffsetHR 0
setenv FC2DAOffsetHR ${CyclingWindowHR}


##################################
# auto-generate cylc include files
##################################

if ( ! -e include/variables/workflow.rc ) then
cat >! include/variables/workflow.rc << EOF
# cycling dates-time information
{% set firstCyclePoint   = "${firstCyclePoint}" %}
{% set initialCyclePoint = "${initialCyclePoint}" %}
{% set finalCyclePoint   = "${finalCyclePoint}" %}
{% set DA2FCOffsetHR = "${DA2FCOffsetHR}" %}
{% set FC2DAOffsetHR = "${FC2DAOffsetHR}" %}

# task selection controls
{% set CriticalPathType = "${CriticalPathType}" %}
{% set VerifyAgainstObservations = ${VerifyAgainstObservations} %} #bool
{% set VerifyAgainstExternalAnalyses = ${VerifyAgainstExternalAnalyses} %} #bool
{% set VerifyDeterministicDA = ${VerifyDeterministicDA} %} #bool
{% set CompareDA2Benchmark = ${CompareDA2Benchmark} %} #bool
{% set VerifyExtendedMeanFC = ${VerifyExtendedMeanFC} %} #bool
{% set VerifyBGMembers = ${VerifyBGMembers} %} #bool
{% set CompareBG2Benchmark = ${CompareBG2Benchmark} %} #bool
{% set VerifyEnsMeanBG = ${VerifyEnsMeanBG} %} #bool
{% set DiagnoseEnsSpreadBG = ${DiagnoseEnsSpreadBG} %} #bool
{% set VerifyANMembers = ${VerifyANMembers} %} #bool
{% set VerifyExtendedEnsFC = ${VerifyExtendedEnsFC} %} #bool

# active cycle points
{% set maxActiveCyclePoints = ${maxActiveCyclePoints} %}
EOF

endif
