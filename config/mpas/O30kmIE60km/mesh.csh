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

## ABI super-obbing footprint, set independently
#  for variational and hofx
#OPTIONS: 15X15, 59X59
set variationalABISuperOb = 15X15
set hofxABISuperOb = 15X15

## AHI super-obbing footprint set independently
#  for variational and hofx
#OPTIONS: 15X15, 101X101
set variationalAHISuperOb = 15X15
set hofxAHISuperOb = 15X15

## Background Error

### Ensemble localization

#### strategy: common
#### 1200km horizontal loc
#### 6km height vertical loc
setenv bumpLocPrefix bumploc_1200km_6km
###### 384pe
#setenv bumpLocDir /glade/p/mmm/parc/guerrett/pandac/fixed_input/60km/bumploc/h=1200km_v=6km_384pe_05OCT2021code
###### 192pe
setenv bumpLocDir /glade/p/mmm/parc/guerrett/pandac/fixed_input/60km/bumploc/h=1200km_v=6km_192pe_05OCT2021code
###### 144pe
#setenv bumpLocDir /glade/p/mmm/parc/guerrett/pandac/fixed_input/60km/bumploc/h=1200km_v=6km_144pe_05OCT2021code
###### 128pe
#setenv bumpLocDir /glade/p/mmm/parc/guerrett/pandac/fixed_input/60km/bumploc/h=1200km_v=6km_128pe_05OCT2021code
###### 96pe
#setenv bumpLocDir /glade/p/mmm/parc/guerrett/pandac/fixed_input/60km/bumploc/h=1200km_v=6km_96pe_05OCT2021code
