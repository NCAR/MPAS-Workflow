#!/bin/csh -f

if ( $?config_rtpp ) exit 0
setenv config_rtpp 1

source config/members.csh
source config/model.csh

source config/scenario.csh rtpp

setenv rtpp__relaxationFactor "`$getLocalOrNone relaxationFactor`"
if ("$rtpp__relaxationFactor" == None) then
  setenv rtpp__relaxationFactor "0.0"
endif

$setLocal retainOriginalAnalyses

setenv AppName rtpp
setenv appyaml ${AppName}.yaml

## job
$setLocal job.retry

foreach parameter (baseSeconds secondsPerMember nodes PEPerNode memory)
  set p = "`$getLocalOrNone job.${ensembleMesh}.${parameter}`"
  if ("$p" == None) then
    set p = "`$getLocalOrNone job.defaults.${parameter}`"
  endif
  if ("$p" == None) then
    echo "config/applications/rtpp.csh (ERROR): invalid value for $paramater"
    exit 1
  endif
  set ${parameter}_ = "$p"
end

@ seconds = $secondsPerMember_ * $nMembers + $baseSeconds_
setenv seconds $seconds


##################################
# auto-generate cylc include files
##################################

if ( ! -e include/tasks/auto/rtpp.rc ) then
cat >! include/tasks/auto/rtpp.rc << EOF
  [[PrepRTPP]]
    inherit = BATCH
    script = \$origin/PrepRTPP.csh
    [[[job]]]
      execution time limit = PT1M
      execution retry delays = ${retry}
  [[RTPP]]
    inherit = BATCH
    script = \$origin/RTPP.csh
    [[[job]]]
      execution time limit = PT${seconds}S
      execution retry delays = ${retry}
    [[[directives]]]
      -m = ae
      -q = {{CPQueueName}}
      -A = {{CPAccountNumber}}
      -l = select=${nodes_}:ncpus=${PEPerNode_}:mpiprocs=${PEPerNode_}:mem=${memory_}GB
  [[CleanRTPP]]
    inherit = CleanBase
    script = \$origin/CleanRTPP.csh
EOF

endif

if ( ! -e include/dependencies/auto/rtpp.rc ) then

if ("$rtpp__relaxationFactor" != "0.0" && $nMembers > 1) then
cat >! include/dependencies/auto/rtpp.rc << EOF
        PrepRTPP => RTPP
        DataAssimPost => RTPP => DataAssimFinished
  {% set CleanDataAssim = CleanDataAssim + ' & CleanRTPP' %}
EOF

else
cat >! include/dependencies/auto/rtpp.rc << EOF
#
EOF

endif
endif
