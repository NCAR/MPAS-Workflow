#!/bin/csh -f

# Uniform 30km mesh - all applications

setenv MPASGridDescriptorOuter 30km
setenv MPASGridDescriptorInner 30km
setenv MPASGridDescriptorEnsemble ${MPASGridDescriptorInner}
setenv MPASnCellsOuter 655362
setenv MPASnCellsInner 655362
setenv MPASnCellsEnsemble ${MPASnCellsInner}
setenv MPASTimeStep 180.0
setenv MPASDiffusionLengthScale 15000.0
setenv RADTHINDISTANCE    "60.0"
setenv RADTHINAMOUNT      "0.75"

## Background Error
setenv bumpLocDir /glade/p/mmm/parc/liuz/pandac_common/30km_bumploc_2000km_512p_20210208code
setenv bumpLocPrefix bumploc_2000_5

## GFS analyses for model-space verification
setenv GFSAnaDirVerify /glade/p/mmm/parc/liuz/pandac_common/${MPASGridDescriptorOuter}_GFSANA
