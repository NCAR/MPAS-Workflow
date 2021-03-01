#!/bin/csh -f

# Uniform 30km mesh
# -----------------
setenv MPASEnsembleGridDescriptor $MPASGridDescriptor
setenv MPASnCells 655362
setenv MPASTimeStep 180.0
setenv MPASDiffusionLengthScale 15000.0
setenv RADTHINDISTANCE    "60.0"
setenv RADTHINAMOUNT      "0.75"

## Background Error
#TODO: add localization files for 30km domain
#setenv bumpLocDir /glade/scratch/bjung/x_bumploc_20210208
#setenv bumpLocPrefix bumploc_2000_5
