#!/bin/csh -f

if ( $?config_externalanalyses ) exit 0
setenv config_externalanalyses 1

source config/model.csh

source config/scenario.csh externalanalyses

$setNestedExternalanalyses resource

# outer
foreach parameter (externalDirectory filePrefix Vtable PrepareExternalAnalysis)
  set p = "`$getLocalOrNone $externalanalyses__resource.$outerMesh.${parameter}`"
  if ("$p" == None) then
    set p = "`$getLocalOrNone $externalanalyses__resource.common.${parameter}`"
  endif
  if ("$p" == None) then
    set p = "`$getLocalOrNone defaults.${parameter}`"
  endif
  set externalanalyses__${parameter} = "$p"
end

set externalanalyses__filePrefix = `echo "$externalanalyses__filePrefix" | sed 's@{{nCells}}@'$nCellsOuter'@'`

#if ("$externalanalyses_externalDirectory" == None && "$externalanalyses_PrepareExternalAnalysis" == ExternalAnalysisReady) then
#  echo "externalanalyses (ERROR): one of externalDirectory or PrepareExternalAnalysis must be defined"
#  exit 1
#endif


# inner
foreach parameter (externalDirectory filePrefix)
  set p = "`$getLocalOrNone $externalanalyses__resource.$innerMesh.${parameter}`"
  if ("$p" == None) then
    set p = "`$getLocalOrNone $externalanalyses__resource.common.${parameter}`"
  endif
  if ("$p" == None) then
    set p = "`$getLocalOrNone defaults.${parameter}`"
  endif
  set externalanalyses__${parameter}Inner = "$p"
end

set externalanalyses__filePrefixInner = `echo "$externalanalyses__filePrefixInner" | sed 's@{{nCells}}@'$nCellsInner'@'`


# ensemble
foreach parameter (externalDirectory filePrefix)
  set p = "`$getLocalOrNone $externalanalyses__resource.$ensembleMesh.${parameter}`"
  if ("$p" == None) then
    set p = "`$getLocalOrNone $externalanalyses__resource.common.${parameter}`"
  endif
  if ("$p" == None) then
    set p = "`$getLocalOrNone defaults.${parameter}`"
  endif
  set externalanalyses__${parameter}Ensemble = "$p"
end

set externalanalyses__filePrefixEnsemble = `echo "$externalanalyses__filePrefixEnsemble" | sed 's@{{nCells}}@'$nCellsEnsemble'@'`

