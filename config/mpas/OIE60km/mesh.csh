#!/bin/csh -f

# Uniform 60km mesh - all applications

setenv MPASGridDescriptorOuter 60km
setenv MPASGridDescriptorInner 60km
setenv MPASGridDescriptorEnsemble ${MPASGridDescriptorInner}
setenv MPASnCellsOuter 163842
setenv MPASnCellsInner 163842
setenv MPASnCellsEnsemble ${MPASnCellsInner}
setenv MPASTimeStep 360.0
setenv MPASDiffusionLengthScale 60000.0
setenv RADTHINDISTANCE     "145.0"
setenv RADTHINAMOUNT       "0.95"

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
setenv bumpCovPrefix mpas_parametersbump_cov
setenv bumpCovDir /glade/scratch/bjung/pandac/20220425_develop/60km.NICAS_00
setenv bumpCovStdDevFile /glade/scratch/bjung/pandac/20220425_develop/60km.CMAT_00/mpas.stddev.2018-04-15_00.00.00.nc
setenv bumpCovVBalPrefix mpas_vbal
setenv bumpCovVBalDir /glade/scratch/bjung/pandac/20220425_develop/60km.VBAL_00

### Ensemble localization

#### strategy: common
#### 1200km horizontal loc
#### 6km height vertical loc
setenv bumpLocPrefix bumploc_1200.0km_6.0km
setenv bumpLocDir /glade/p/mmm/parc/guerrett/pandac/fixed_input/60km/bumploc/h=1200.0km_v=6.0km_25APR2022code

#OLD CODE VERSIONS, TODO: replicate with new code
#### 5 level vert loc
#setenv bumpLocPrefix bumploc_2000_5
###### 384pe
#setenv bumpLocDir /glade/p/mmm/parc/liuz/pandac_common/60km_bumploc_2000km_384p_20210903code

#### strategy: specific_multivariate
#### 1200km horizontal loc (dynamic)
#### 6km height vertical loc (dynamic)
#### 600km horizontal loc (cloud)
#### 3km height vertical loc (cloud)
#setenv bumpLocPrefix bumploc_1200.0km_6.0km_hydro600.0km_hydro3.0km
#setenv bumpLocDir /glade/scratch/bjung/xx_loc_strategy/60km/test.io_keys_values.resol6.universe_clean
