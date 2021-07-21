#!/bin/csh -f

####################################
## workflow-relevant state variables
####################################
setenv MPASJEDIDiagVariables cldfrac
setenv MPASSeaVariables sst,xice
set MPASHydroVariables = (qc qi qg qr qs cldfrac)

set StandardAnalysisVariables = ( \
  spechum \
  surface_pressure \
  temperature \
  uReconstructMeridional \
  uReconstructZonal \
)
set StandardStateVariables = ( \
  $StandardAnalysisVariables \
  theta \
  rho \
  u \
  qv \
  pressure \
  landmask \
  xice \
  snowc \
  skintemp \
  ivgtyp \
  isltyp \
  snowh \
  vegfra \
  u10 \
  v10 \
  lai \
  smois \
  tslb \
  pressure_p \
)

set MPASJEDIVariablesFiles = (geovars.yaml)
