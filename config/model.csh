#!/bin/csh -f

# only load model if it is not already loaded
if ( $?config_model ) exit 0
setenv config_model 1

source config/scenario.csh model

## MPASCore - must be atmosphere
setenv MPASCore atmosphere

## meshes
# outerMesh is mandatory for all drivers/*.csh
# innerMesh and ensembleMesh are mandatory for driver/Cycle.csh
$setLocal outerMesh
setenv innerMesh "`$getLocalOrNone innerMesh`"
setenv ensembleMesh "`$getLocalOrNone ensembleMesh`"

setenv nCellsOuter "`$getLocalOrNone nCells.$outerMesh`"
setenv nCellsInner "`$getLocalOrNone nCells.$innerMesh`"
setenv nCellsEnsemble "`$getLocalOrNone nCells.$ensembleMesh`"

# list of all meshes formatted to be fed to a jinja2 command
set allMeshesJinja = '["'$outerMesh'", "'$innerMesh'", "'$ensembleMesh'"]'

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
