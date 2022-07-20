#!/bin/csh

####################################################################################################
# This script runs a pre-configure cylc suite scenario described in config/scenario.csh. If the user
# has previously executed this script with the same effecitve "SuiteName" the scenario is
# already running, then executing this script will automatically kill those running suites.
####################################################################################################

## general-purpose experimental cycling

echo "$0 (INFO): generating a new cylc suite"

date

echo "$0 (INFO): Initializing the MPAS-Workflow experiment directory"
# Create the experiment directory and cylc task scripts
source drivers/SetupWorkflow.csh "cycling"

## Change to the cylc suite directory
cd ${mainScriptDir}

echo "$0 (INFO): loading the workflow-relevant parts of the configuration"

# included application-independent configurations
source config/experiment.csh
source config/externalanalyses.csh
source config/firstbackground.csh
source config/job.csh
source config/model.csh
source config/observations.csh
source config/workflow.csh

# setup application-specific cylc tasks
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

set cylcWorkDir = /glade/scratch/${USER}/cylc-run
mkdir -p ${cylcWorkDir}

echo "$0 (INFO): Generating the suite.rc file"
cat >! suite.rc << EOF
#!Jinja2
# cycling dates-time information
{% set AnalysisTimes = "${AnalysisTimes}" %}
{% set ForecastTimes = "${ForecastTimes}" %}

%include include/variables/experiment.rc
%include include/variables/extendedforecast.rc
%include include/variables/externalanalyses.rc
%include include/variables/firstbackground.rc
%include include/variables/job.rc
%include include/variables/model.rc
%include include/variables/observations.rc
%include include/variables/workflow.rc

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

## (iv.a) Critical path
%include include/dependencies/criticalpath.rc

## (iv.b) Verification
  {% if VerifyAgainstExternalAnalyses %}
%include include/dependencies/verifymodel.rc
  {% endif %}

  {% if VerifyAgainstObservations %}
%include include/dependencies/verifyobs.rc
  {% endif %}

[runtime]
%include include/tasks/base.rc
%include include/tasks/criticalpath.rc
%include include/tasks/externalmodel.rc
%include include/tasks/observations.rc
%include include/tasks/verify.rc

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
