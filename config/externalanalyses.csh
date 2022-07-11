#!/bin/csh -f

if ( $?config_externalanalyses ) exit 0
setenv config_externalanalyses 1

source config/model.csh

source config/scenario.csh externalanalyses

$setNestedExternalanalyses resource

# outer
set name = Outer
set mesh = "$outerMesh"
set ncells = "$nCellsOuter"
foreach parameter (externalDirectory filePrefix Vtable UngribPrefix PrepareExternalAnalysisTasks)
  set p = "`$getLocalOrNone $externalanalyses__resource.$mesh.${parameter}`"
  if ("$p" == None) then
    set p = "`$getLocalOrNone $externalanalyses__resource.common.${parameter}`"
  endif
  if ("$p" == None) then
    set p = "`$getLocalOrNone defaults.${parameter}`"
  endif
  if ("$parameter" == filePrefix) then
    set externalanalyses__${parameter}${name} = `echo "$p" | sed 's@{{nCells}}@'$ncells'@'`
  else if ("$parameter" == PrepareExternalAnalysisTasks) then
    set tmp = ""
    foreach task ($p)
      set tmp = "$tmp"`echo '"'$task'"' | sed 's@mesh@'$mesh'@g'`", "
    end
    set externalanalyses__${parameter}${name} = "$tmp"
  else
    set externalanalyses__${parameter}${name} = "$p"
  endif
end

# assume UngribPrefix and Vtable are always identical across meshes
set externalanalyses__UngribPrefix = "$externalanalyses__UngribPrefixOuter"
unset externalanalyses__UngribPrefixOuter

set externalanalyses__Vtable = "$externalanalyses__VtableOuter"
unset externalanalyses__VtableOuter

# inner
set name = Inner
set mesh = "$innerMesh"
set ncells = "$nCellsInner"
foreach parameter (externalDirectory filePrefix PrepareExternalAnalysisTasks)
  set p = "`$getLocalOrNone $externalanalyses__resource.$mesh.${parameter}`"
  if ("$p" == None) then
    set p = "`$getLocalOrNone $externalanalyses__resource.common.${parameter}`"
  endif
  if ("$p" == None) then
    set p = "`$getLocalOrNone defaults.${parameter}`"
  endif
  if ("$parameter" == filePrefix) then
    set externalanalyses__${parameter}${name} = `echo "$p" | sed 's@{{Cells}}@'$ncells'@'`
  else if ("$parameter" == PrepareExternalAnalysisTasks) then
    set tmp = ""
    foreach task ($p)
      set tmp = "$tmp"`echo '"'$task'"' | sed 's@mesh@'$mesh'@g'`", "
    end
    set externalanalyses__${parameter}${name} = "$tmp"
  else
    set externalanalyses__${parameter}${name} = "$p"
  endif
end

# ensemble
set name = Ensemble
set mesh = "$ensembleMesh"
set ncells = "$nCellsEnsemble"
foreach parameter (externalDirectory filePrefix PrepareExternalAnalysisTasks)
  set p = "`$getLocalOrNone $externalanalyses__resource.$mesh.${parameter}`"
  if ("$p" == None) then
    set p = "`$getLocalOrNone $externalanalyses__resource.common.${parameter}`"
  endif
  if ("$p" == None) then
    set p = "`$getLocalOrNone defaults.${parameter}`"
  endif
  if ("$parameter" == filePrefix) then
    set externalanalyses__${parameter}${name} = `echo "$p" | sed 's@{{nCells}}@'$ncells'@'`
  else if ("$parameter" == PrepareExternalAnalysisTasks) then
    set tmp = ""
    foreach task ($p)
      set tmp = "$tmp"`echo '"'$task'"' | sed 's@mesh@'$mesh'@g'`", "
    end
    set externalanalyses__${parameter}${name} = "$tmp"
  else
    set externalanalyses__${parameter}${name} = "$p"
  endif
end
