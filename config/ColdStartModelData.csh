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
setenv updateSea 0
setenv StaticFieldsDirOuter ${GFSAnaDirOuter}/${FirstCycleDate}
setenv StaticFieldsDirInner ${GFSAnaDirInner}/${FirstCycleDate}
