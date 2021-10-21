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
# Last updated 08 Feb 2021
# works for 36pe/128pe and 120km domain
setenv bumpLocDir /glade/p/mmm/parc/bjung/pandac_common/bumploc/20210811
setenv bumpLocPrefix bumploc_2000_5

## GFS analyses for model-space verification
setenv GFSAnaDirVerify /glade/p/mmm/parc/liuz/pandac_common/${MPASGridDescriptorOuter}_GFSANA
