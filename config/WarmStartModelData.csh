#!/bin/csh -f

source config/experiment.csh
source config/filestructure.csh
source config/tools.csh
source config/mpas/${MPASGridDescriptor}/mesh.csh


####################
## static data files
####################
## common directories
set ModelData = /glade/p/mmm/parc/guerrett/pandac/fixed_input
set OuterModelData = ${ModelData}/${MPASGridDescriptorOuter}
set InnerModelData = ${ModelData}/${MPASGridDescriptorInner}
set EnsembleModelData = ${ModelData}/${MPASGridDescriptorEnsemble}

set GFSAnaDirOuter = ${OuterModelData}/GFSAna
set GFSAnaDirInner = ${InnerModelData}/GFSAna
set GFSAnaDirEnsemble = ${EnsembleModelData}/GFSAna

setenv InitICWorkDir  ${GFSAnaDirOuter}

exit 0
