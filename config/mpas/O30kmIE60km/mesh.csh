#!/bin/csh -f

# Uniform 30km mesh -- forecast, hofx, variational outer loop
# Uniform 60km mesh -- variational inner loop

setenv MPASGridDescriptorOuter 30km
setenv MPASGridDescriptorInner 60km
setenv MPASGridDescriptorEnsemble ${MPASGridDescriptorInner}
setenv MPASnCellsOuter 655362
setenv MPASnCellsInner 163842
setenv MPASnCellsEnsemble ${MPASnCellsInner}
setenv MPASTimeStep 180.0
setenv MPASDiffusionLengthScale 30000.0
setenv RADTHINDISTANCE    "100.0"
setenv RADTHINAMOUNT      "0.75"

## Background Error

### Static B

#### control variables: [stream_function, velocity_potential, temperature, spechum, surface_pressure]
#### strategy: specific_univariate
set bumpCovControlVariables = ( \
  stream_function \
  velocity_potential \
  temperature \
  spechum \
  surface_pressure \
)
setenv bumpCovPrefix None
setenv bumpCovDir None
setenv bumpCovStdDevFile None
setenv bumpCovVBalPrefix None
setenv bumpCovVBalDir None

### Ensemble localization

#### strategy: common
#### 1200km horizontal loc
#### 6km height vertical loc
setenv bumpLocPrefix bumploc_1200.0km_6.0km
setenv bumpLocDir /glade/p/mmm/parc/guerrett/pandac/fixed_input/60km/bumploc/h=1200.0km_v=6.0km_16MAR2022code
