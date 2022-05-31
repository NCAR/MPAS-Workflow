#!/bin/csh

####################################################################################################
# This script runs the TestName script in order to confirm that basic functionalities work under
# cylc that a developer has already confirmed work on a login node and/or in an interactive job.
# It is meant to be a minimal test that avoids the complex dependencies of MPAS-Workflow config
# and task scripts.
####################################################################################################


set TestName = TestConda
set SuiteName = ${TestName}

setenv mainScriptDir /glade/scratch/${USER}/pandac/${SuiteName}/MPAS-Workflow
mkdir -p /glade/scratch/${USER}/pandac/${SuiteName}/MPAS-Workflow

set workflowParts = ( \
  ../tools \
  ../config \
  ../scenarios \
  ${TestName}.csh \
)
foreach part ($workflowParts)
  cp -rP $part ${mainScriptDir}/
end

## Change to the cylc suite directory
cd ${mainScriptDir}

set cylcWorkDir = /glade/scratch/${USER}/cylc-run
mkdir -p ${cylcWorkDir}

echo "$0 (INFO): Generating the suite.rc file"
cat >! suite.rc << EOF
#!Jinja2
## Import relevant environment variables as Jinja2 variables
# main suite directory
{% set mainScriptDir = "${mainScriptDir}" %}
[meta]
  title = "${SuiteName}"

[cylc]
  UTC mode = False
  [[environment]]
[scheduling]
  initial cycle point = 20180415T00
  final cycle point   = 20180415T00

  [[dependencies]]
    [[[R1]]]
      graph = ${TestName}
[runtime]
## Root
  [[root]] # suite defaults
    init-script = '''
source /etc/profile.d/modules.sh
module load conda/latest
conda activate npl
which python
python --version
pip list
'''
    pre-script = "cd  \$origin/"
    [[[environment]]]
      origin = {{mainScriptDir}}
    # PBS
    [[[job]]]
      batch system = pbs
      execution time limit = PT5M
    [[[directives]]]
      -j = oe
      -k = eod
      -S = /bin/tcsh
      # default to using one processor
      -q = casper@casper-pbs
      -A = NMMM0015
      -l = select=1:ncpus=1
  [[${TestName}]]
    script = \$origin/${TestName}.csh
[visualization]
  initial cycle point = 20180415T00
  final cycle point   = 20180415T00
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
