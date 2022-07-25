#!/bin/csh -f

if ( $?config_verifyobs ) exit 0
setenv config_verifyobs 1

source config/members.csh

source config/scenario.csh verifyobs

$setLocal pyVerifyDir

## job
$setLocal job.retry

foreach parameter (baseSeconds secondsPerMember)
  set p = "`$getLocalOrNone job.${parameter}`"
  if ("$p" == None) then
    echo "config/applications/verifyobs.csh (ERROR): invalid value for $paramater"
    exit 1
  endif
  set ${parameter}_ = "$p"
end

@ seconds = $secondsPerMember_ * $nMembers + $baseSeconds_
setenv verifyobsens__seconds $seconds


##################################
# auto-generate cylc include files
##################################

if ( ! -e include/tasks/auto/verifyobsbase.rc ) then
cat >! include/tasks/auto/verifyobsbase.rc << EOF
  [[VerifyObsBase]]
    inherit = BATCH
    [[[job]]]
      execution time limit = PT${baseSeconds_}S
      execution retry delays = ${retry}
    [[[directives]]]
      -q = {{NCPQueueName}}
      -A = {{NCPAccountNumber}}
      -l = select=1:ncpus=36:mpiprocs=36

{% if DiagnoseEnsSpreadBG %}
  {% set nEnsSpreadMem = ${nMembers} %}
  {% set obsEnsSeconds = ${verifyobsens__seconds} %}
{% else %}
  {% set nEnsSpreadMem = 0 %}
  {% set obsEnsSeconds = ${baseSeconds_} %}
{% endif %}
EOF

endif

