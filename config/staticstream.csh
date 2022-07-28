#!/bin/csh -f

if ( $?config_staticstream ) exit 0
setenv config_staticstream 1

source config/auto/members.csh
source config/auto/model.csh
source config/auto/scenario.csh staticstream

setenv staticstream__resource "`$getLocalOrNone resource`"

#outer
set name = Outer
set mesh = "$outerMesh"
set ncells = "$nCellsOuter"
foreach parameter (directory filePrefix maxMembers memberFormat)
  set p = "`$getLocalOrNone $staticstream__resource.$mesh.${parameter}`"
  if ("$p" == None) then
    set p = "`$getLocalOrNone $staticstream__resource.common.${parameter}`"
  endif
  if ("$p" == None) then
    set p = "`$getLocalOrNone defaults.${parameter}`"
  endif
  if ("$parameter" == filePrefix) then
    set staticstream__${parameter}${name} = `echo "$p" | sed 's@{{nCells}}@'$ncells'@'`
  else
    set staticstream__${parameter}${name} = "$p"
  endif
end
if ($nMembers > $staticstream__maxMembersOuter) then
  echo "staticstream (ERROR): nMembers must be <= maxMembersOuter ($staticstream__maxMembersOuter)"
  exit 1
endif
if ("$staticstream__directoryOuter" == None) then
  echo "staticstream (ERROR): directory must be defined"
  exit 1
endif

#inner
set name = Inner
set mesh = "$innerMesh"
set ncells = "$nCellsInner"
foreach parameter (directory filePrefix)
  set p = "`$getLocalOrNone $staticstream__resource.$mesh.${parameter}`"
  if ("$p" == None) then
    set p = "`$getLocalOrNone $staticstream__resource.common.${parameter}`"
  endif
  if ("$p" == None) then
    set p = "`$getLocalOrNone defaults.${parameter}`"
  endif
  if ("$parameter" == filePrefix) then
    set staticstream__${parameter}${name} = `echo "$p" | sed 's@{{nCells}}@'$ncells'@'`
  else
    set staticstream__${parameter}${name} = "$p"
  endif
end

#ensemble
set name = Ensemble
set mesh = "$ensembleMesh"
set ncells = "$nCellsEnsemble"
foreach parameter (directory filePrefix)
  set p = "`$getLocalOrNone $staticstream__resource.$mesh.${parameter}`"
  if ("$p" == None) then
    set p = "`$getLocalOrNone $staticstream__resource.common.${parameter}`"
  endif
  if ("$p" == None) then
    set p = "`$getLocalOrNone defaults.${parameter}`"
  endif
  if ("$parameter" == filePrefix) then
    set staticstream__${parameter}${name} = `echo "$p" | sed 's@{{nCells}}@'$ncells'@'`
  else
    set staticstream__${parameter}${name} = "$p"
  endif
end
