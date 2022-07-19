#!/bin/csh

####################################################################################################
# This script runs a pre-configure cylc suite scenario described in config/scenario.csh. If the user
# has previously executed this script with the same effecitve "SuiteName" the scenario is
# already running, then executing this script will automatically kill those running suites.
####################################################################################################

## external analyses generation for real-time or a historical period

echo "$0 (INFO): generating a new cylc suite"

date

echo "$0 (INFO): Initializing the MPAS-Workflow experiment directory"
# Create the experiment directory and cylc task scripts
source drivers/SetupWorkflow.csh "base"

## Change to the cylc suite directory
cd ${mainScriptDir}

echo "$0 (INFO): loading the workflow-relevant parts of the configuration"

# cross-application settings
source config/experiment.csh
source config/externalanalyses.csh
source config/job.csh
source config/model.csh
source config/workflow.csh

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
{% set GenerateTimes = "${GenerateTimes}" %}

# members
{% set nMembers = ${nMembers} %} #integer
{% set allMembers = range(1, nMembers+1, 1) %}
{% set outerMesh = "$outerMesh" %}

# common job controls
{% set CPQueueName = "${CPQueueName}" %}
{% set CPAccountNumber = "${CPAccountNumber}" %}
{% set NCPQueueName = "${NCPQueueName}" %}
{% set NCPAccountNumber = "${NCPAccountNumber}" %}
{% set SingleProcQueueName = "${SingleProcQueueName}" %}
{% set SingleProcAccountNumber = "${SingleProcAccountNumber}" %}

{% set InitializationRetry = "${InitializationRetry}" %}
{% set GetAnalysisRetry = "${GetAnalysisRetry}" %}
{% set CleanRetry = "${CleanRetry}" %}

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

# task selection controls
{% set CriticalPathType = "${CriticalPathType}" %}

# Active cycle points
{% set maxActiveCyclePoints = ${maxActiveCyclePoints} %}

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
  max active cycle points = {{maxActiveCyclePoints}}

  [[dependencies]]

    [[[{{GenerateTimes}}]]]
      graph = {{PrepareExternalAnalysisOuter}}

[runtime]
%include include/tasks/base.rc
%include include/tasks/externalmodel.rc

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
