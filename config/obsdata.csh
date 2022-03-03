#!/bin/csh -f

if ( $?config_obsdata ) exit 0
set config_obsdata = 1

## InterpolationType
# controls the horizontal interpolation used in variational and hofx applications
# OPTIONS: bump, unstructured
setenv InterpolationType unstructured

##############
# Fixed tables
##############
## CRTM
setenv CRTMTABLES ${FixedInput}/crtm_bin/
