#!/bin/csh -f

# Uniform 120km mesh - all applications

setenv MPASGridDescriptorOuter 120km
setenv MPASGridDescriptorInner 120km
setenv MPASGridDescriptorEnsemble ${MPASGridDescriptorInner}
setenv MPASnCellsOuter 40962
setenv MPASnCellsInner 40962
setenv MPASnCellsEnsemble ${MPASnCellsInner}
setenv MPASTimeStep 720.0
setenv MPASDiffusionLengthScale 120000.0
setenv RADTHINDISTANCE     "200.0"
setenv RADTHINAMOUNT       "0.98"
setenv ABEILocalizationRadius "1200.0"

## ABI super-obbing footprint, set independently
#  for variational and hofx
#OPTIONS: 15X15, 59X59
set variationalABISuperOb = 59X59
set hofxABISuperOb = 59X59

## AHI super-obbing footprint set independently
#  for variational and hofx
#OPTIONS: 15X15, 101X101
set variationalAHISuperOb = 101X101
set hofxAHISuperOb = 101X101

## Background Error

### Ensemble localization

#### strategy: common

#### 2000km horizontal loc
#### 5 level vertical loc
# works for 36pe/128pe and 120km domain
#setenv bumpLocDir /glade/p/mmm/parc/bjung/pandac_common/bumploc/20210811
#setenv bumpLocPrefix bumploc_2000_5

#### 1200km horizontal loc
#### 6km height vertical loc
# 128pe only
setenv bumpLocPrefix bumploc_1200.0km_6.0km
setenv bumpLocDir /glade/p/mmm/parc/guerrett/pandac/fixed_input/120km/bumploc/h=1200.0km_v=6.0km_128pe_05OCT2021code
