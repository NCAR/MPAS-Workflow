#!/bin/csh -f

source config/model.csh
source config/experiment.csh

####################
## static data files
####################
## common directories
set OuterModelData = /glade/p/mmm/parc/guerrett/pandac/fixed_input/${outerMesh}
set InnerModelData = /glade/p/mmm/parc/guerrett/pandac/fixed_input/${innerMesh}
set EnsembleModelData = /glade/p/mmm/parc/guerrett/pandac/fixed_input/${ensembleMesh}

set GFSAnaDirOuter = ${OuterModelData}/GFSAna
set GFSAnaDirInner = ${InnerModelData}/GFSAna
set GFSAnaDirEnsemble = ${EnsembleModelData}/GFSAna

setenv GFSAnaDirVerify ${GFSAnaDirOuter}
setenv InitICWorkDir ${GFSAnaDirOuter}
setenv SeaFilePrefix x1.${nCellsOuter}.sfc_update

if ($nMembers == 1) then
  setenv StaticFieldsDirOuter ${GFSAnaDirOuter}
  setenv StaticFieldsDirInner ${GFSAnaDirInner}
endif
