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

## GDAS observations error table
# This file provides observation errors for all types of conventional and satwnd data
# for 33 pressure levels (1100 hPa to 0 hPa). More information on this table can be 
# found in the GSI User's guide (https://dtcenter.ucar.edu/com-GSI/users/docs/users_guide/GSIUserGuide_v3.7.pdf)
setenv GDASObsErrtable ${FixedInput}/GSI_errtables/HRRRENS_errtable_10sep2018.r3dv
