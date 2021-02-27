#!/bin/csh -f

# Uniform 120km mesh
# ------------------
echo "loading settings for 120km mesh"
setenv MPASEnsembleGridDescriptor $MPASGridDescriptor
setenv MPASnCells 40962
setenv MPASTimeStep 720.0
setenv MPASDiffusionLengthScale 120000.0
setenv RADTHINDISTANCE     "200.0"
setenv RADTHINAMOUNT       "0.98"
