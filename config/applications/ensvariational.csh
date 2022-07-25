#!/bin/csh -f

if ( $?config_ensvariational ) exit 0
setenv config_ensvariational 1

source config/model.csh
source config/applications/variational.csh

source config/scenario.csh ensvariational

## job
$setLocal job.retry

foreach parameter (baseSeconds secondsPerEnVarMember nodesPerMember PEPerNode memory)
  set p = "`$getLocalOrNone job.${outerMesh}.${parameter}`"
  if ("$p" == None) then
    set p = "`$getLocalOrNone job.defaults.${parameter}`"
  endif
  if ("$p" == None) then
    echo "config/applications/ensvariational.csh (ERROR): invalid value for $paramater"
    exit 1
  endif
  set ${parameter}_ = "$p"
end

@ seconds = $secondsPerEnVarMember_ * $ensPbNMembers + $baseSeconds_
setenv seconds $seconds

@ nodes = $nodesPerMember_ * $EDASize
setenv nodes $nodes


##################################
# auto-generate cylc include files
##################################

cat >! include/tasks/auto/ensvariational.rc << EOF
  # single instance or ensemble of EDA(s)
{% if ${EDASize} > 1 %}
  {% for inst in range(1, ${nDAInstances}+1, 1) %}
  [[EDAInstance{{inst}}]]
    inherit = DataAssim
    script = \$origin/applications/EnsembleOfVariational.csh "{{inst}}"
    [[[job]]]
      execution time limit = PT${seconds}S
      execution retry delays = ${retry}
    [[[directives]]]
      -m = ae
      -q = {{CPQueueName}}
      -A = {{CPAccountNumber}}
      -l = select=${nodes}:ncpus=${PEPerNode_}:mpiprocs=${PEPerNode_}:mem=${memory_}GB
  {% endfor %}
{% endif %}
EOF

