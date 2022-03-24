#!/bin/csh

####################################################################################################
# This script runs a pre-configure cylc suite scenario described in config/scenario.csh. If the user
# has previously executed this script with the same effecitve "SuiteName" the scenario is
# already running, then executing this script will automatically kill those running suites.
####################################################################################################

echo "$0 (INFO): generating a new cylc suite"

date

echo "$0 (INFO): loading the workflow-relevant parts of the configuration"

source config/filestructure.csh
source config/workflow.csh
source config/observations.csh
source config/model.csh
source config/variational.csh
source config/job.csh
source config/mpas/${MPASGridDescriptor}/job.csh

echo "$0 (INFO):  ExperimentName = ${ExperimentName}"

echo "$0 (INFO): setting up the environment"

module purge
module load cylc
module load graphviz

date

## SuiteName: name of the cylc suite, can be used to differentiate between two
# suites running simultaneously in the same ${ExperimentName} directory
#
# default: ${ExperimentName}
# example: ${ExperimentName}_verify for a simultaneous suite running only Verification
set SuiteName = ${ExperimentName}

# Differentiate between creating the workflow suite for the first time
# and restarting (i.e., when initialCyclePoint > firstCyclePoint)
if ($initialCyclePoint == $firstCyclePoint) then
  echo "$0 (INFO): Initializing ${PackageBaseName} in the experiment directory"
  # Create the experiment directory and cylc task scripts
  ./SetupWorkflow.csh

  # The analysis will run every CyclingWindowHR hours, starting CyclingWindowHR hours after the
  # initialCyclePoint
  set AnalysisTimes = +PT${CyclingWindowHR}H/PT${CyclingWindowHR}H

  # The forecast will run every CyclingWindowHR hours, starting CyclingWindowHR+DA2FCOffsetHR hours
  # after the initialCyclePoint
  @ ColdFCOffset = ${CyclingWindowHR} + ${DA2FCOffsetHR}
  set ForecastTimes = +PT${ColdFCOffset}H/PT${CyclingWindowHR}H
else
  # The analysis will run every CyclingWindowHR hours, starting at the initialCyclePoint
  set AnalysisTimes = PT${CyclingWindowHR}H

  # The forecast will run every CyclingWindowHR hours, starting DA2FCOffsetHR hours after the
  # initialCyclePoint
  set ForecastTimes = +PT${DA2FCOffsetHR}H/PT${CyclingWindowHR}H
endif

## Change to the cylc suite directory
cd ${mainScriptDir}

set cylcWorkDir = /glade/scratch/${USER}/cylc-run
mkdir -p ${cylcWorkDir}

echo "$0 (INFO): Generating the suite.rc file"
cat >! suite.rc << EOF
#!Jinja2
## Import environment variables as Jinja2 settings
# main suite directory
{% set mainScriptDir = "${mainScriptDir}" %}

# cycling dates-time information
{% set firstCyclePoint   = "${firstCyclePoint}" %}
{% set initialCyclePoint = "${initialCyclePoint}" %}
{% set finalCyclePoint   = "${finalCyclePoint}" %}
{% set AnalysisTimes = "${AnalysisTimes}" %}
{% set ForecastTimes = "${ForecastTimes}" %}
{% set DA2FCOffsetHR = "${DA2FCOffsetHR}" %}
{% set FC2DAOffsetHR = "${FC2DAOffsetHR}" %}
{% set ExtendedMeanFCTimes = "${ExtendedMeanFCTimes}" %}
{% set ExtendedEnsFCTimes = "${ExtendedEnsFCTimes}" %}
{% set ExtendedFCWindowHR = ${ExtendedFCWindowHR} %} #integer
{% set ExtendedFC_DT_HR = ${ExtendedFC_DT_HR} %} #integer

# initialization type
{% set InitializationType = "${InitializationType}" %}

# eda
{% set EDASize = ${EDASize} %} #integer
{% set nDAInstances = ${nDAInstances} %} #integer
{% set nEnsDAMembers = ${nEnsDAMembers} %} #integer
{% set EnsDAMembers = range(1, nEnsDAMembers+1, 1) %}
{% set DAInstances = range(1, nDAInstances+1, 1) %}

# inflation
{% set RTPPInflationFactor = ${RTPPInflationFactor} %}
{% set ABEInflation = ${ABEInflation} %}

# common job controls
{% set CPQueueName = "${CPQueueName}" %}
{% set CPAccountNumber = "${CPAccountNumber}" %}
{% set NCPQueueName = "${NCPQueueName}" %}
{% set NCPAccountNumber = "${NCPAccountNumber}" %}
{% set SingleProcQueueName = "${SingleProcQueueName}" %}
{% set SingleProcAccountNumber = "${SingleProcAccountNumber}" %}
{% set EnsMeanBGQueueName = "${EnsMeanBGQueueName}" %}
{% set EnsMeanBGAccountNumber = "${EnsMeanBGAccountNumber}" %}

{% set InitializationRetry = "${InitializationRetry}" %}
{% set GFSAnalysisRetry = "${GFSAnalysisRetry}" %}
{% set GetObsRetry = "${GetObsRetry}" %}
{% set VariationalRetry = "${VariationalRetry}" %}
{% set EnsOfVariationalRetry = "${EnsOfVariationalRetry}" %}
{% set CyclingFCRetry = "${CyclingFCRetry}" %}
{% set RTPPInflationRetry = "${RTPPInflationRetry}" %}
{% set HofXRetry = "${HofXRetry}" %}
{% set CleanRetry = "${CleanRetry}" %}

# mesh-specific job controls
{% set CyclingFCJobMinutes = "${CyclingFCJobMinutes}" %}
{% set CyclingFCNodes = "${CyclingFCNodes}" %}
{% set CyclingFCPEPerNode = "${CyclingFCPEPerNode}" %}

{% set CyclingInflationJobMinutes = "${CyclingInflationJobMinutes}" %}
{% set CyclingInflationNodes = "${CyclingInflationNodes}" %}
{% set CyclingInflationPEPerNode = "${CyclingInflationPEPerNode}" %}
{% set CyclingInflationMemory = "${CyclingInflationMemory}" %}

{% set EnsOfVariationalJobMinutes = "${EnsOfVariationalJobMinutes}" %}
{% set EnsOfVariationalNodes = "${EnsOfVariationalNodes}" %}
{% set EnsOfVariationalPEPerNode = "${EnsOfVariationalPEPerNode}" %}
{% set EnsOfVariationalMemory = "${EnsOfVariationalMemory}" %}

{% set ExtendedFCJobMinutes = "${ExtendedFCJobMinutes}" %}
{% set ExtendedFCNodes = "${ExtendedFCNodes}" %}
{% set ExtendedFCPEPerNode = "${ExtendedFCPEPerNode}" %}

{% set HofXJobMinutes = "${HofXJobMinutes}" %}
{% set HofXNodes = "${HofXNodes}" %}
{% set HofXPEPerNode = "${HofXPEPerNode}" %}
{% set HofXMemory = "${HofXMemory}" %}

{% set InitICJobMinutes = "${InitICJobMinutes}" %}
{% set InitICNodes = "${InitICNodes}" %}
{% set InitICPEPerNode = "${InitICPEPerNode}" %}

{% set VariationalJobMinutes = "${VariationalJobMinutes}" %}
{% set VariationalNodes = "${VariationalNodes}" %}
{% set VariationalPEPerNode = "${VariationalPEPerNode}" %}
{% set VariationalMemory = "${VariationalMemory}" %}

{% set VerifyModelJobMinutes = "${VerifyModelJobMinutes}" %}
{% set VerifyObsJobMinutes = "${VerifyObsJobMinutes}" %}
{% set VerifyObsEnsMeanJobMinutes = "${VerifyObsEnsMeanJobMinutes}" %}

# task selection controls
{% set CriticalPathType = "${CriticalPathType}" %}
{% set VerifyDeterministicDA = ${VerifyDeterministicDA} %} #bool
{% set CompareDA2Benchmark = ${CompareDA2Benchmark} %} #bool
{% set VerifyExtendedMeanFC = ${VerifyExtendedMeanFC} %} #bool
{% set VerifyBGMembers = ${VerifyBGMembers} %} #bool
{% set CompareBG2Benchmark = ${CompareBG2Benchmark} %} #bool
{% set VerifyEnsMeanBG = ${VerifyEnsMeanBG} %} #bool
{% set DiagnoseEnsSpreadBG = ${DiagnoseEnsSpreadBG} %} #bool
{% set VerifyANMembers = ${VerifyANMembers} %} #bool
{% set VerifyExtendedEnsFC = ${VerifyExtendedEnsFC} %} #bool

## Import composite tasks with sub-task dependecies
%include include/composite-tasks.rc

[meta]
  title = "${PackageBaseName}--${SuiteName}"

[cylc]
  UTC mode = False
  [[environment]]
[scheduling]
  initial cycle point = {{initialCyclePoint}}
  final cycle point   = {{finalCyclePoint}}

  # Maximum number of simultaneous active dates;
  # useful for constraining non-blocking flows
  # and to avoid over-utilization of login nodes
  # hint: execute 'ps aux | grep $USER' to check your login node overhead
  # default: 3
{% if CriticalPathType != "Normal" %}
  max active cycle points = 20
{% else %}
  max active cycle points = 4
{% endif %}

  [[dependencies]]
## (1) Critical path for firstCyclePoint
{% if initialCyclePoint == firstCyclePoint %}
    [[[R1]]]
      graph = '''{{firstCycleCriticalPath}}'''
{% endif %}

## (2) Critical path
    [[[{{AnalysisTimes}}]]]
      graph = '''{{DACriticalPath}}'''

    [[[{{ForecastTimes}}]]]
      graph = '''{{FCCriticalPath}}'''

## (3) Verification
%include include/verification.rc

[runtime]
%include include/basic-tasks.rc

[visualization]
  initial cycle point = {{initialCyclePoint}}
  final cycle point   = {{finalCyclePoint}}
  number of cycle points = 200
  default node attributes = "style=filled", "fillcolor=grey"
EOF

cylc poll $SuiteName >& /dev/null
if ( $status == 0 ) then
  echo "$0 (INFO): a cylc suite named $SuiteName is already running!"
  echo "$0 (INFO): stopping the suite, then starting a new one"
  cylc stop --kill $SuiteName
  sleep 5
else
  echo "$0 (INFO): confirmed that a cylc suite named $SuiteName is not running"
  echo "$0 (INFO): starting a new suite"
endif

rm -rf ${cylcWorkDir}/${SuiteName}

cylc register ${SuiteName} ${mainScriptDir}
cylc validate --strict ${SuiteName}
cylc run ${SuiteName}

exit 0
