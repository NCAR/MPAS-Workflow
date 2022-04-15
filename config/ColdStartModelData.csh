#!/bin/csh -f

source config/filestructure.csh
source config/model.csh
source config/applications/variational.csh

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

if ($nEnsDAMembers == 1) then
  setenv StaticFieldsDirOuter ${GFSAnaDirOuter}/${FirstCycleDate}
  setenv StaticFieldsDirInner ${GFSAnaDirInner}/${FirstCycleDate}
endif
