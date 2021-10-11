#!/bin/csh -f

# Uniform 120km mesh
# ------------------
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
# Last updated 08 Feb 2021
# works for 36pe/128pe and 120km domain
setenv bumpLocDir /glade/p/mmm/parc/bjung/pandac_common/bumploc/20210811
setenv bumpLocPrefix bumploc_2000_5
