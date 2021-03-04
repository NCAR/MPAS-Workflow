#!/bin/csh -f

# Uniform 120km mesh
# ------------------
setenv MPASEnsembleGridDescriptor $MPASGridDescriptor
setenv MPASnCells 40962
setenv MPASTimeStep 720.0
setenv MPASDiffusionLengthScale 120000.0
setenv RADTHINDISTANCE     "200.0"
setenv RADTHINAMOUNT       "0.98"

## Background Error
# Last updated 08 Feb 2021
# works for 36pe/128pe and 120km domain
setenv bumpLocDir /glade/scratch/bjung/x_bumploc_20210208
setenv bumpLocPrefix bumploc_2000_5
