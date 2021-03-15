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
setenv MPASDiffusionLengthScale 15000.0
setenv RADTHINDISTANCE    "60.0"
setenv RADTHINAMOUNT      "0.75"

## Background Error
# Last updated 08 Feb 2021
# works for 36pe/128pe and 120km domain
setenv bumpLocDir /glade/scratch/bjung/x_bumploc_20210208
setenv bumpLocPrefix bumploc_2000_5
