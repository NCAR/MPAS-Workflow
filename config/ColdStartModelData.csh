#!/bin/csh -f

source config/experiment.csh
source config/filestructure.csh
source config/tools.csh
source config/mpas/${MPASGridDescriptor}/mesh.csh


####################
## static data files
####################
## common directories
set OuterModelData = ${ExpDir}/${MPASGridDescriptorOuter}
set InnerModelData = ${ExpDir}/${MPASGridDescriptorInner}
set EnsembleModelData = ${ExpDir}/${MPASGridDescriptorEnsemble}

set GFSAnaDirOuter = ${OuterModelData}/GFSAna
set GFSAnaDirInner = ${InnerModelData}/GFSAna
set GFSAnaDirEnsemble = ${EnsembleModelData}/GFSAna

setenv InitICWorkDir  ${GFSAnaDirOuter}

exit 0

