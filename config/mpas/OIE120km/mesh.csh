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
# works for 36pe/128pe and 120km domain
setenv bumpLocDir /glade/p/mmm/parc/bjung/pandac_common/bumploc/20210811
setenv bumpLocPrefix bumploc_2000_5
