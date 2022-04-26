#!/bin/csh -f

# Uniform 30km mesh -- forecast, hofx, variational outer loop
# Uniform 120km mesh -- variational inner loop

setenv MPASGridDescriptorOuter 30km
setenv MPASGridDescriptorInner 120km
setenv MPASGridDescriptorEnsemble ${MPASGridDescriptorInner}
setenv MPASnCellsOuter 655362
setenv MPASnCellsInner 40962
setenv MPASnCellsEnsemble ${MPASnCellsInner}
setenv MPASTimeStep 180.0
setenv MPASDiffusionLengthScale 30000.0
setenv RADTHINDISTANCE    "145.0"
setenv RADTHINAMOUNT      "0.75"

## Background Error

### Static B
# TODO: should static B correspond to the inner or outer loop mesh?

#### control variables: [stream_function, velocity_potential, temperature, spechum, surface_pressure]
#### strategy: specific_univariate
set bumpCovControlVariables = ( \
  stream_function \
  velocity_potential \
  temperature \
  spechum \
  surface_pressure \
)
setenv bumpCovPrefix mpas_parametersbump_cov
setenv bumpCovDir /glade/scratch/bjung/pandac/20220425_develop/NICAS_00
setenv bumpCovStdDevFile /glade/scratch/bjung/pandac/20220425_develop/CMAT_00/mpas.stddev.2018-04-15_00.00.00.nc
setenv bumpCovVBalPrefix mpas_vbal
setenv bumpCovVBalDir /glade/scratch/bjung/pandac/20220425_develop/VBAL_00

### Ensemble localization

#### strategy: common

#### 1200km horizontal loc
#### 6km height vertical loc
setenv bumpLocPrefix bumploc_1200.0km_6.0km
setenv bumpLocDir /glade/p/mmm/parc/guerrett/pandac/fixed_input/120km/bumploc/h=1200.0km_v=6.0km_25APR2022code
