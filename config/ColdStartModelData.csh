#!/bin/csh -f

source config/filestructure.csh
source config/model.csh

####################
## static data files
####################
## common directories
set OuterModelData = ${ExperimentDirectory}/${outerMesh}
set InnerModelData = ${ExperimentDirectory}/${innerMesh}
set EnsembleModelData = ${ExperimentDirectory}/${ensembleMesh}

set GFSAnaDirOuter = ${OuterModelData}/GFSAna
set GFSAnaDirInner = ${InnerModelData}/GFSAna
set GFSAnaDirEnsemble = ${EnsembleModelData}/GFSAna

setenv InitICWorkDir ${GFSAnaDirOuter}
setenv SeaFilePrefix ${InitFilePrefixOuter}

if ( "$DAType" !~ *"eda"* ) then
  setenv StaticFieldsDirOuter ${GFSAnaDirOuter}/${FirstCycleDate}
  setenv StaticFieldsDirInner ${GFSAnaDirInner}/${FirstCycleDate}
endif
