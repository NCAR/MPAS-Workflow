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
setenv RADTHINDISTANCE    "60.0"
setenv RADTHINAMOUNT      "0.75"

## Background Error

### Ensemble localization

#### strategy: common

#### 1200km horizontal loc
#### 6km height vertical loc
setenv bumpLocPrefix bumploc_1200.0km_6.0km
setenv bumpLocDir /glade/p/mmm/parc/guerrett/pandac/fixed_input/120km/bumploc/h=1200.0km_v=6.0km_28FEB2022code
