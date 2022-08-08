#!/bin/csh

####################################################################################################
# This script runs a pre-configure cylc suite scenario described in config/scenario.csh. If the user
# has previously executed this script with the same effecitve "SuiteName" the scenario is
# already running, then executing this script will automatically kill those running suites.
####################################################################################################

echo "$0 (INFO): generating a new cylc suite"

date

echo "$0 (INFO): Initializing the MPAS-Workflow experiment directory"
# Create the experiment directory and cylc task scripts
source SetupWorkflow.csh

## Change to the cylc suite directory
cd ${mainScriptDir}

echo "$0 (INFO): loading the workflow-relevant parts of the configuration"

# cross-application settings
source config/experiment.csh
source config/firstbackground.csh
source config/externalanalyses.csh
source config/job.csh
source config/model.csh
source config/observations.csh
source config/workflow.csh

# application-specific settings, including resource requests
source config/applications/ensvariational.csh
source config/applications/forecast.csh $outerMesh
source config/applications/hofx.csh
source config/applications/initic.csh
source config/applications/rtpp.csh
source config/applications/variational.csh
source config/applications/verifyobs.csh
source config/applications/verifymodel.csh

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
set GenerateTimes = PT${CyclingWindowHR}H

set cylcWorkDir = /glade/scratch/${USER}/cylc-run
mkdir -p ${cylcWorkDir}

echo "$0 (INFO): Generating the suite.rc file"
cat >! suite.rc << EOF
#!Jinja2
## Import relevant environment variables as Jinja2 variables
# main suite directory
{% set mainScriptDir = "${mainScriptDir}" %}

# cycling dates-time information
{% set firstCyclePoint   = "${firstCyclePoint}" %}
{% set initialCyclePoint = "${initialCyclePoint}" %}
{% set finalCyclePoint   = "${finalCyclePoint}" %}
{% set AnalysisTimes = "${AnalysisTimes}" %}
{% set ForecastTimes = "${ForecastTimes}" %}
{% set GenerateTimes = "${GenerateTimes}" %}
{% set DA2FCOffsetHR = "${DA2FCOffsetHR}" %}
{% set FC2DAOffsetHR = "${FC2DAOffsetHR}" %}
{% set ExtendedMeanFCTimes = "${ExtendedMeanFCTimes}" %}
{% set ExtendedEnsFCTimes = "${ExtendedEnsFCTimes}" %}
{% set forecastIAU = ${forecast__IAU} %} #bool
{% set FCOutIntervalHR = ${FCOutIntervalHR} %} #integer
{% set FCLengthHR = ${FCLengthHR} %} #integer
{% set ExtendedFCOutIntervalHR = ${ExtendedFCOutIntervalHR} %} #integer
{% set ExtendedFCLengthHR = ${ExtendedFCLengthHR} %} #integer
{% set ExtendedFCLengths = range(0, ExtendedFCLengthHR+ExtendedFCOutIntervalHR, ExtendedFCOutIntervalHR) %}

# observation information
{% set observationsResource = "${observations__resource}" %}
{% set GetGDASAnalysis = ${GetGDASAnalysis} %} #bool

# members
{% set nMembers = ${nMembers} %} #integer
{% set allMembers = range(1, nMembers+1, 1) %}
{% set EnsVerifyMembers = allMembers %}
{% set allMeshes = ${allMeshesJinja} %} #list
{% set outerMesh = "$outerMesh" %}

# variational
{% set EDASize = ${EDASize} %} #integer
{% set nDAInstances = ${nDAInstances} %} #integer
{% set DAInstances = range(1, nDAInstances+1, 1) %}

# inflation
{% set RTPPRelaxationFactor = ${rtpp__relaxationFactor} %}
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
{% set RTPPRetry = "${RTPPRetry}" %}
{% set HofXRetry = "${HofXRetry}" %}
{% set CleanRetry = "${CleanRetry}" %}
{% set VerifyObsRetry = "${VerifyObsRetry}" %}
{% set VerifyModelRetry = "${VerifyModelRetry}" %}

# mesh-specific job controls
{% set CyclingFCSeconds = "${forecast__seconds}" %}
{% set CyclingFCNodes = "${forecast__nodes}" %}
{% set CyclingFCPEPerNode = "${forecast__PEPerNode}" %}

{% set RTPPSeconds = "${rtpp__seconds}" %}
{% set RTPPNodes = "${rtpp__nodes}" %}
{% set RTPPPEPerNode = "${rtpp__PEPerNode}" %}
{% set RTPPMemory = "${rtpp__memory}" %}

{% set EnsOfVariationalSeconds = "${ensvariational__seconds}" %}
{% set EnsOfVariationalNodes = "${ensvariational__nodes}" %}
{% set EnsOfVariationalPEPerNode = "${ensvariational__PEPerNode}" %}
{% set EnsOfVariationalMemory = "${ensvariational__memory}" %}

{% set ExtendedFCSeconds = "${extendedforecast__seconds}" %}
{% set ExtendedFCNodes = "${forecast__nodes}" %}
{% set ExtendedFCPEPerNode = "${forecast__PEPerNode}" %}

{% set HofXSeconds = "${hofx__seconds}" %}
{% set HofXNodes = "${hofx__nodes}" %}
{% set HofXPEPerNode = "${hofx__PEPerNode}" %}
{% set HofXMemory = "${hofx__memory}" %}

## Mini-workflows that prepare cold-start initial condition files from an external analysis
{% set PrepareExternalAnalysisTasksOuter = [${externalanalyses__PrepareExternalAnalysisTasksOuter}] %}
{% set PrepareExternalAnalysisOuter = " => ".join(PrepareExternalAnalysisTasksOuter) %}

{% set PrepareExternalAnalysisTasksInner = [${externalanalyses__PrepareExternalAnalysisTasksInner}] %}
{% set PrepareExternalAnalysisInner = " => ".join(PrepareExternalAnalysisTasksInner) %}

{% set PrepareExternalAnalysisTasksEnsemble = [${externalanalyses__PrepareExternalAnalysisTasksEnsemble}] %}
{% set PrepareExternalAnalysisEnsemble = " => ".join(PrepareExternalAnalysisTasksEnsemble) %}

{% set PrepareFirstBackgroundOuter = "${firstbackground__PrepareFirstBackgroundOuter}" %}

{% set InitICSeconds = "${initic__seconds}" %}
{% set InitICNodes = "${initic__nodes}" %}
{% set InitICPEPerNode = "${initic__PEPerNode}" %}

{% set VariationalSeconds = "${variational__seconds}" %}
{% set VariationalNodes = "${variational__nodes}" %}
{% set VariationalPEPerNode = "${variational__PEPerNode}" %}
{% set VariationalMemory = "${variational__memory}" %}

{% set VerifyModelSeconds = "${verifymodel__seconds}" %}
{% set VerifyModelEnsMeanSeconds = "${verifymodelens__seconds}" %}

{% set VerifyObsSeconds = "${verifyobs__seconds}" %}
{% set VerifyObsEnsMeanSeconds = "${verifyobsens__seconds}" %}

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

# Active cycle points
{% set maxActiveCyclePoints = ${maxActiveCyclePoints} %}

## Mini-workflow that prepares observations for IODA ingest
{% if observationsResource == "PANDACArchive" %}
  # assume that IODA observation files are already available for PANDACArchive case
  {% set PrepareObservations = "ObsReady" %}
{% else %}
  {% set PrepareObservations = "GetObs => ObsToIODA => ObsReady" %}
{% endif %}

# Use external analysis for sea surface updating
{% set PrepareSeaSurfaceUpdate = PrepareExternalAnalysisOuter %}


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
  max active cycle points = {{maxActiveCyclePoints}}
{% endif %}

  [[dependencies]]

{% if CriticalPathType == "GenerateExternalAnalyses" %}
## (i) External analyses generation for a historical period
    [[[{{GenerateTimes}}]]]
      graph = {{PrepareExternalAnalysisOuter}}

{% elif CriticalPathType == "GenerateObs" %}
## (ii) Observation generation for a historical period
    [[[{{GenerateTimes}}]]]
      graph = {{PrepareObservations}}

{% else %}

## (iii.a) Critical path
%include include/criticalpath.rc

## (iii.b) Verification
  {% if VerifyAgainstExternalAnalyses %}
%include include/verifymodel.rc
  {% endif %}

  {% if VerifyAgainstObservations %}
%include include/verifyobs.rc
  {% endif %}

{% endif %}

[runtime]
%include include/tasks.rc

[visualization]
  initial cycle point = {{initialCyclePoint}}
  final cycle point   = {{finalCyclePoint}}
  number of cycle points = 200
  default node attributes = "style=filled", "fillcolor=grey"
EOF

cylc poll $SuiteName >& /dev/null
if ( $status == 0 ) then
  echo "$0 (INFO): a cylc suite named $SuiteName is already running!"
  echo "$0 (INFO): stopping the suite (30 sec.), then starting a new one..."
  cylc stop --kill $SuiteName
  sleep 30
else
  echo "$0 (INFO): confirmed that a cylc suite named $SuiteName is not running"
  echo "$0 (INFO): starting a new suite..."
endif

rm -rf ${cylcWorkDir}/${SuiteName}

cylc register ${SuiteName} ${mainScriptDir}
cylc validate --strict ${SuiteName}
cylc run ${SuiteName}

exit 0
