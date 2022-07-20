#!/bin/csh -f

# only load hofx if it is not already loaded
# note: set must be used instead of setenv, because some of the setLocal commands apply to
# lists, which use set instead of setenv
if ( $?config_hofx ) exit 0
set config_hofx = 1

source config/model.csh
source config/scenario.csh hofx

## required settings for PrepJEDI.csh
$setLocal observations

setenv AppName hofx
setenv appyaml ${AppName}.yaml

set MeshList = (HofX)
set nCellsList = ($nCellsOuter)
set StreamsFileList = ($outerStreamsFile)
set NamelistFileList = ($outerNamelistFile)

$setLocal nObsIndent

$setLocal biasCorrection
$setLocal radianceThinningDistance
$setLocal tropprsMethod
$setLocal maxIODAPoolSize

## clean
$setLocal retainObsFeedback

## job
$setLocal job.retry

foreach parameter (seconds nodes PEPerNode memory)
  set p = "`$getLocalOrNone job.${outerMesh}.${parameter}`"
  if ("$p" == None) then
    set p = "`$getLocalOrNone job.defaults.${parameter}`"
  endif
  if ("$p" == None) then
    echo "config/applications/hofx.csh (ERROR): invalid value for $paramater"
    exit 1
  endif
  set ${parameter}_ = "$p"
end


##################################
# auto-generate cylc include files
##################################

if ( ! -e include/tasks/auto/hofxbase.rc ) then
cat >! include/tasks/auto/hofxbase.rc << EOF
  [[HofXBase]]
    inherit = BATCH
    [[[job]]]
      execution time limit = PT${seconds_}S
      execution retry delays = ${retry}
    [[[directives]]]
      -q = {{NCPQueueName}}
      -A = {{NCPAccountNumber}}
      -l = select=${nodes_}:ncpus=${PEPerNode_}:mpiprocs=${PEPerNode_}:mem=${memory_}GB
EOF

endif
