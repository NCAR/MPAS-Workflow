#!/bin/csh

####################################################################################################
# This script runs a pre-configure cylc suite scenario described in config/scenario.csh. If the user
# has previously executed this script with the same effecitve "SuiteName" the scenario is
# already running, then executing this script will automatically kill those running suites.
####################################################################################################

## external analyses generation for real-time or a historical period

set appIndependentConfigs = (externalanalyses job model workflow)
set appDependentConfigs = ()
set ExpConfigType = base

echo "$0 (INFO): generating a new cylc suite"

date

# application-independent configurations
foreach c ($appIndependentConfigs)
  ./config/${c}.csh
end

echo "$0 (INFO): Initializing the MPAS-Workflow experiment directory"
# Create the experiment directory and cylc task scripts
source drivers/SetupWorkflow.csh "$ExpConfigType"

## Change to the cylc suite directory
cd ${mainScriptDir}

echo "$0 (INFO): loading the workflow-relevant parts of the configuration"

# experiment-specific configuration
source config/experiment.csh

# application-specific configurations
foreach app ($appDependentConfigs)
  ./config/applications/${app}.csh
end

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

set cylcWorkDir = /glade/scratch/${USER}/cylc-run
mkdir -p ${cylcWorkDir}

echo "$0 (INFO): Generating the suite.rc file"
cat >! suite.rc << EOF
#!Jinja2

%include include/variables/auto/experiment.rc
%include include/variables/auto/externalanalyses.rc
%include include/variables/auto/job.rc
%include include/variables/auto/model.rc
%include include/variables/auto/workflow.rc

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

    [[[PT{{CyclingWindowHR}}H]]]
      graph = {{PrepareExternalAnalysisOuter}}

[runtime]
%include include/tasks/base.rc
%include include/tasks/auto/externalanalyses.rc
%include include/tasks/auto/initic.rc

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

# clean up auto-generated rc files
cd -
rm include/*/auto/*.rc

exit 0
