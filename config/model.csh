#!/bin/csh -f

# only load model if it is not already loaded
if ( $?config_model ) exit 0
setenv config_model 1

source config/scenario.csh

# setLocal is a helper function that picks out a configuration node
# under the "model" key of scenarioConfig
setenv baseConfig scenarios/base/model.yaml
setenv setLocal "source $setConfig $baseConfig $scenarioConfig model"
setenv setNestedModel "source $setNestedConfig $baseConfig $scenarioConfig model"
setenv getLocalOrNone "source $getConfigOrNone $baseConfig $scenarioConfig model"

## MPASCore - must be atmosphere
setenv MPASCore atmosphere

$setLocal outerMesh
$setLocal innerMesh
$setLocal ensembleMesh

setenv MeshesDescriptor O
if ("$outerMesh" != "$innerMesh") then
  setenv MeshesDescriptor ${MeshesDescriptor}${outerMesh}
endif
setenv MeshesDescriptor ${MeshesDescriptor}I
if ("$innerMesh" != "$ensembleMesh") then
  #TODO: remove when this is no longer a limitation
  echo "$0 (ERROR): innerMesh ($innerMesh) must equal ensembleMesh($ensembleMesh)"
  exit 1
  #setenv MeshesDescriptor ${MeshesDescriptor}${innerMesh}
endif
setenv MeshesDescriptor ${MeshesDescriptor}E${ensembleMesh}

setenv nCellsOuter "`$getLocalOrNone nCells.$outerMesh`"
setenv nCellsInner "`$getLocalOrNone nCells.$innerMesh`"
setenv nCellsEnsemble "`$getLocalOrNone nCells.$ensembleMesh`"

$setLocal ${outerMesh}.TimeStep
$setLocal ${outerMesh}.DiffusionLengthScale

$setNestedModel AnalysisSource

$setLocal GraphInfoDir

$setNestedModel precision


setenv ModelConfigDir config/mpas

# MPAS-Model file-naming conventions
setenv InitFilePrefixOuter x1.${nCellsOuter}.init
setenv InitFilePrefixInner x1.${nCellsInner}.init
setenv InitFilePrefixEnsemble x1.${nCellsEnsemble}.init

setenv StreamsFile streams.${MPASCore}
setenv NamelistFile namelist.${MPASCore}
set OuterStreamsFile = ${StreamsFile}_${outerMesh}
set OuterNamelistFile = ${NamelistFile}_${outerMesh}
set InnerStreamsFile = ${StreamsFile}_${innerMesh}
set InnerNamelistFile = ${NamelistFile}_${innerMesh}

#set EnsembleStreamsFile = ${StreamsFile}_${ensembleMesh}
#set EnsembleNamelistFile = ${NamelistFile}_${ensembleMesh}

setenv StreamsFileInit streams.init_${MPASCore}
setenv NamelistFileInit namelist.init_${MPASCore}
setenv NamelistFileWPS namelist.wps

setenv TemplateFieldsPrefix templateFields
setenv TemplateFieldsFileOuter ${TemplateFieldsPrefix}.${nCellsOuter}.nc
setenv TemplateFieldsFileInner ${TemplateFieldsPrefix}.${nCellsInner}.nc
setenv TemplateFieldsFileEnsemble ${TemplateFieldsPrefix}.${nCellsEnsemble}.nc

setenv localStaticFieldsPrefix static
setenv localStaticFieldsFileOuter ${localStaticFieldsPrefix}.${nCellsOuter}.nc
setenv localStaticFieldsFileInner ${localStaticFieldsPrefix}.${nCellsInner}.nc
setenv localStaticFieldsFileEnsemble ${localStaticFieldsPrefix}.${nCellsEnsemble}.nc
