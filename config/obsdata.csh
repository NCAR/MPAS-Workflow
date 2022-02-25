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
set FixedInput = /glade/work/guerrett/pandac/fixed_input

## CRTM
setenv CRTMTABLES ${FixedInput}/crtm_bin/

## VARBC
setenv INITIAL_VARBC_TABLE ${FixedInput}/satbias/satbias_crtm_in
