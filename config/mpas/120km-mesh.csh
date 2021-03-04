#!/bin/csh -f

# Uniform 120km mesh
# ------------------
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
setenv bumpLocDir /glade/scratch/bjung/x_bumploc_20210208
setenv bumpLocPrefix bumploc_2000_5
