#!/bin/csh -f

source config/filestructure.csh
source config/model.csh

####################
## static data files
####################
## common directories
set ModelData = /glade/p/mmm/parc/guerrett/pandac/fixed_input
set OuterModelData = ${ModelData}/${outerMesh}
set InnerModelData = ${ModelData}/${innerMesh}
set EnsembleModelData = ${ModelData}/${ensembleMesh}

set GFSAnaDirOuter = ${OuterModelData}/GFSAna
set GFSAnaDirInner = ${InnerModelData}/GFSAna
set GFSAnaDirEnsemble = ${EnsembleModelData}/GFSAna

setenv GFSAnaDirVerify ${GFSAnaDirOuter}
setenv InitICWorkDir  ${GFSAnaDirOuter}
setenv SeaFilePrefix x1.${nCellsOuter}.sfc_update

if ( "$DAType" !~ *"eda"* ) then
  setenv StaticFieldsDirOuter ${GFSAnaDirOuter}
  setenv StaticFieldsDirInner ${GFSAnaDirInner}
endif
