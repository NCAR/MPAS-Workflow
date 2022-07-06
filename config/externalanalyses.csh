#!/bin/csh -f

if ( $?config_externalanalyses ) exit 0
setenv config_externalanalyses 1

source config/scenario.csh
source config/model.csh

# setLocal is a helper function that picks out a configuration node
# under the "externalanalyses" key of scenarioConfig
setenv baseConfig scenarios/base/externalanalyses.yaml
setenv setLocal "source $setConfig $baseConfig $scenarioConfig externalanalyses"
setenv getLocalOrNone "source $getConfigOrNone $baseConfig $scenarioConfig externalanalyses"
setenv setNestedExternalAnalyses "source $setNestedConfig $baseConfig $scenarioConfig externalanalyses"

$setNestedExternalAnalyses resource

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

