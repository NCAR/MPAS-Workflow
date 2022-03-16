#!/bin/csh -f

source config/workflow.csh
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

setenv updateSea 1

## static stream data
if ( "$DAType" =~ *"eda"* ) then
  # stochastic
  # 60km and 120km
  setenv StaticFieldsDirOuter ${ModelData}/GEFS/init/000hr/${FirstCycleDate}
  setenv StaticFieldsDirInner ${ModelData}/GEFS/init/000hr/${FirstCycleDate}
  setenv StaticFieldsDirEnsemble ${ModelData}/GEFS/init/000hr/${FirstCycleDate}
  setenv staticMemFmt "${gefsMemFmt}"

  #TODO: switch to using FirstFileDate static files for GEFS
  setenv StaticFieldsFileOuter ${InitFilePrefixOuter}.${FirstFileDate}.nc
  setenv StaticFieldsFileInner ${InitFilePrefixInner}.${FirstFileDate}.nc
  setenv StaticFieldsFileEnsemble ${InitFilePrefixEnsemble}.${FirstFileDate}.nc
else
  # deterministic
  # 30km, 60km, and 120km
  setenv StaticFieldsDirOuter ${GFSAnaDirOuter}
  setenv StaticFieldsDirInner ${GFSAnaDirInner}
  setenv StaticFieldsFileOuter ${InitFilePrefixOuter}.${FirstFileDate}.nc
  setenv StaticFieldsFileInner ${InitFilePrefixInner}.${FirstFileDate}.nc
  setenv StaticFieldsFileEnsemble ${InitFilePrefixEnsemble}.${FirstFileDate}.nc
  setenv GFSAnaDirVerify ${GFSAnaDirOuter}
endif
