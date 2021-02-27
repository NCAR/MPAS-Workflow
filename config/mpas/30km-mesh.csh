#!/bin/csh -f

## Uniform 30km mesh
## -----------------
echo "loading settings for 30km mesh"
setenv MPASEnsembleGridDescriptor $MPASGridDescriptor
setenv MPASnCells 655362
setenv MPASTimeStep 180.0
setenv MPASDiffusionLengthScale 15000.0
setenv RADTHINDISTANCE    "60.0"
setenv RADTHINAMOUNT      "0.75"
