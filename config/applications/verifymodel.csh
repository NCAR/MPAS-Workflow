#!/bin/csh -f

if ( $?config_verifymodel ) exit 0
setenv config_verifymodel 1

source config/model.csh
source config/experiment.csh
source config/scenario.csh verifymodel

$setLocal pyVerifyDir

## job
$setLocal job.retry

foreach parameter (baseSeconds secondsPerMember)
  set p = "`$getLocalOrNone job.${outerMesh}.${parameter}`"
  if ("$p" == None) then
    set p = "`$getLocalOrNone job.defaults.${parameter}`"
  endif
  if ("$p" == None) then
    echo "config/applications/verifymodel.csh (ERROR): invalid value for $paramater"
    exit 1
  endif
  set ${parameter}_ = "$p"
end

@ seconds = $secondsPerMember_ * $nMembers + $baseSeconds_
setenv verifymodelens__seconds $seconds


##################################
# auto-generate cylc include files
##################################

if ( ! -e include/tasks/verifymodelbase.rc ) then 
cat >! include/tasks/verifymodelbase.rc << EOF
  [[VerifyModelBase]]
    inherit = BATCH
    [[[job]]]
      execution time limit = PT${baseSeconds_}S
      execution retry delays = ${retry}
    [[[directives]]]
      -q = {{NCPQueueName}}
      -A = {{NCPAccountNumber}}
      -l = select=1:ncpus=36:mpiprocs=36

{% if DiagnoseEnsSpreadBG %}
  {% set nEnsSpreadMem = nMembers %}
  {% set modelEnsSeconds = ${verifymodelens__seconds} %}
{% else %}
  {% set nEnsSpreadMem = 0 %}
  {% set modelEnsSeconds = ${baseSeconds_} %}
{% endif %}
EOF

endif
