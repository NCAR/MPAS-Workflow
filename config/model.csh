#!/bin/csh -f

# only load model if it is not already loaded
if ( $?config_model ) exit 0
setenv config_model 1

source config/scenario.csh model

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

# lists of mesh characteristics useful for carrying out identical tasks on each one
#set allMeshesJinja = '["Outer", "Inner", "Ensemble"]'
set allMeshesJinja = '["'$outerMesh'", "'$innerMesh'", "'$ensembleMesh'"]'

# not needed yet...much easier in python than csh
#set allMeshNames = (Outer Inner Ensemble)
#set allMeshes = ($outerMesh $innerMesh $ensembleMesh)
#set allCells = ($nCellsOuter $nCellsInner $nCellsEnsemble)

$setLocal ${outerMesh}.TimeStep
$setLocal ${outerMesh}.DiffusionLengthScale

$setLocal GraphInfoDir

$setNestedModel precision


# MPAS-Model file-naming conventions
setenv InitFilePrefixOuter x1.${nCellsOuter}.init
setenv InitFilePrefixInner x1.${nCellsInner}.init
setenv InitFilePrefixEnsemble x1.${nCellsEnsemble}.init

setenv StreamsFile streams.${MPASCore}
setenv NamelistFile namelist.${MPASCore}
setenv outerStreamsFile ${StreamsFile}_${outerMesh}
setenv outerNamelistFile ${NamelistFile}_${outerMesh}
setenv innerStreamsFile ${StreamsFile}_${innerMesh}
setenv innerNamelistFile ${NamelistFile}_${innerMesh}
#setenv ensembleStreamsFile ${StreamsFile}_${ensembleMesh}
#setenv ensembleNamelistFile ${NamelistFile}_${ensembleMesh}

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
