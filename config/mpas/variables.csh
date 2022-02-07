#!/bin/csh -f

####################################
## workflow-relevant state variables
####################################
setenv MPASJEDIDiagVariables cldfrac
setenv MPASSeaVariables sst,xice
set MPASHydroIncrementVariables = (qc qi qg qr qs)
set MPASHydroStateVariables = (${MPASHydroIncrementVariables} cldfrac)

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
# Jake has t2m+q2 in state variables and stream_list.atmosphere.output
#  t2m \
#  q2 \
#)
set MPASJEDIVariablesFiles = (geovars.yaml)
