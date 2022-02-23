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
# Last updated 08 Feb 2021
# works for 36pe/128pe and 120km domain
setenv bumpLocDir /glade/p/mmm/parc/bjung/pandac_common/bumploc/20210811
setenv bumpLocPrefix bumploc_2000_5
