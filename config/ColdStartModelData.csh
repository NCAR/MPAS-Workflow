#!/bin/csh -f

source config/filestructure.csh
source config/tools.csh
source config/mpas/${MPASGridDescriptor}/mesh.csh

####################
## static data files
####################
## common directories
set OuterModelData = ${ExperimentDirectory}/${MPASGridDescriptorOuter}
set InnerModelData = ${ExperimentDirectory}/${MPASGridDescriptorInner}
set EnsembleModelData = ${ExperimentDirectory}/${MPASGridDescriptorEnsemble}

set GFSAnaDirOuter = ${OuterModelData}/GFSAna
set GFSAnaDirInner = ${InnerModelData}/GFSAna
set GFSAnaDirEnsemble = ${EnsembleModelData}/GFSAna

setenv InitICWorkDir ${GFSAnaDirOuter}
# TODO: enable sea-surface file generation, then turn on sea-surface updating
setenv updateSea 0
if ( "$DAType" !~ *"eda"* ) then
  setenv StaticFieldsDirOuter ${GFSAnaDirOuter}/${FirstCycleDate}
  setenv StaticFieldsDirInner ${GFSAnaDirInner}/${FirstCycleDate}
endif
