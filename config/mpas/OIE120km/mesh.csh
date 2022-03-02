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

## Background Error

### Ensemble localization

#### strategy: common

#### 1200km horizontal loc
#### 6km height vertical loc
setenv bumpLocPrefix bumploc_1200.0km_6.0km
setenv bumpLocDir /glade/p/mmm/parc/guerrett/pandac/fixed_input/120km/bumploc/h=1200.0km_v=6.0km_28FEB2022code
