#!/bin/csh -f

source config/appindex.csh

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


##########################
# Cycle-dependent Datasets
##########################

## Conventional instruments
setenv ConventionalObsDir /glade/p/mmm/parc/liuz/pandac_common/ioda_obs_v2/2018/conv_obs

## Polar MW (amsua, mhs)
# bias correction
set PolarMWNoBias = no_bias
set PolarMWGSIBC = bias_corr
setenv PolarMWBiasCorrect $PolarMWGSIBC

# directories
set basePolarMWObsDir = /glade/p/mmm/parc/liuz/pandac_common/ioda_obs_v2/2018
set PolarMWObsDir = ()
foreach application (${applicationIndex})
  set PolarMWObsDir = ($PolarMWObsDir \
    ${basePolarMWObsDir} \
  )
end
set PolarMWObsDir[$variationalIndex] = $PolarMWObsDir[$variationalIndex]/$PolarMWBiasCorrect

# no bias correction for hofx
set PolarMWObsDir[$hofxIndex] = $PolarMWObsDir[$hofxIndex]/$PolarMWNoBias

## Geostationary IR (abi, ahi)
# bias correction
set GEOIRNoBias = _no-bias-correct
set GEOIRClearBC = _const-bias-correct

setenv ABIBiasCorrect $GEOIRNoBias
foreach obs ($variationalObsList)
  if ( "$obs" =~ "clrabi"* ) then
    setenv ABIBiasCorrect $GEOIRClearBC
  endif
end

setenv AHIBiasCorrect $GEOIRNoBias
foreach obs ($variationalObsList)
  if ( "$obs" =~ "clrahi"* ) then
    setenv AHIBiasCorrect $GEOIRClearBC
  endif
end

# abi directories
set ABITopObsDir = /glade/work/guerrett/pandac/obs/ABIASR/ioda-v2
set baseABIObsDir = ${ABITopObsDir}/IODANC_THIN15KM_SUPEROB
set ABIObsDir = ()
foreach SuperOb ($ABISuperOb)
  set ABIObsDir = ($ABIObsDir \
    ${baseABIObsDir}${SuperOb} \
  )
end
set ABIObsDir[$variationalIndex] = $ABIObsDir[$variationalIndex]$ABIBiasCorrect

# no bias correction for hofx
set ABIObsDir[$hofxIndex] = $ABIObsDir[$hofxIndex]$GEOIRNoBias

# ahi directories
set AHITopObsDir = /glade/work/guerrett/pandac/obs/AHIASR/ioda-v2
set baseAHIObsDir = ${AHITopObsDir}/IODANC_SUPEROB
#Note: AHI is linked from /glade/work/wuyl/pandac/work/fix_input/AHI_OBS
set AHIObsDir = ()
foreach SuperOb ($AHISuperOb)
  set AHIObsDir = ($AHIObsDir \
    ${baseAHIObsDir}${SuperOb} \
  )
end
set AHIObsDir[$variationalIndex] = $AHIObsDir[$variationalIndex]$AHIBiasCorrect

# no bias correction for hofx
set AHIObsDir[$hofxIndex] = $AHIObsDir[$hofxIndex]$GEOIRNoBias
