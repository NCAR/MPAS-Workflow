#!/bin/csh -f

if ( $?config_initic ) exit 0
setenv config_initic 1

source config/auto/model.csh

source config/auto/scenario.csh initic

setenv AppName initic

## job
$setLocal job.retry

foreach parameter (seconds nodes PEPerNode)
  set p = "`$getLocalOrNone job.${outerMesh}.${parameter}`"
  if ("$p" == None) then
    set p = "`$getLocalOrNone job.defaults.${parameter}`"
  endif
  if ("$p" == None) then
    echo "config/applications/forecast.csh (ERROR): invalid value for $paramater"
    exit 1
  endif
  set ${parameter}_ = "$p"
end


##################################
# auto-generate cylc include files
##################################

if ( ! -e include/tasks/auto/initic.rc ) then
cat >! include/tasks/auto/initic.rc << EOF
{% for mesh in allMeshes %}
  [[ExternalAnalysisToMPAS-{{mesh}}]]
    inherit = BATCH
    script = \$origin/applications/ExternalAnalysisToMPAS.csh "{{mesh}}"
    [[[job]]]
      execution time limit = PT${seconds_}S
      execution retry delays = ${retry}
    [[[directives]]]
      -q = {{CPQueueName}}
      -A = {{CPAccountNumber}}
      -l = select=${nodes_}:ncpus=${PEPerNode_}:mpiprocs=${PEPerNode_}
{% endfor %}
EOF

endif
