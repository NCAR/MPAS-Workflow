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
setenv RADTHINDISTANCE     "120.0"
setenv RADTHINAMOUNT       "0.95"

## Background Error

### Ensemble localization

#### strategy: common
#### 1200km horizontal loc
#### 6km height vertical loc
setenv bumpLocPrefix bumploc_1200km_6km
###### 384pe
#setenv bumpLocDir /glade/p/mmm/parc/guerrett/pandac/fixed_input/60km/bumploc/h=1200km_v=6km_384pe_05OCT2021code
###### 192pe - preferred for 80-member EnVar based on wall-time and memory benchmarking
setenv bumpLocDir /glade/p/mmm/parc/guerrett/pandac/fixed_input/60km/bumploc/h=1200km_v=6km_192pe_05OCT2021code
###### 144pe
#setenv bumpLocDir /glade/p/mmm/parc/guerrett/pandac/fixed_input/60km/bumploc/h=1200km_v=6km_144pe_05OCT2021code
###### 128pe
#setenv bumpLocDir /glade/p/mmm/parc/guerrett/pandac/fixed_input/60km/bumploc/h=1200km_v=6km_128pe_05OCT2021code
###### 96pe
#setenv bumpLocDir /glade/p/mmm/parc/guerrett/pandac/fixed_input/60km/bumploc/h=1200km_v=6km_96pe_05OCT2021code

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
