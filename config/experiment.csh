#!/bin/csh -f

# only load experiment if it is not already loaded
# note: set must be used instead of setenv, because this script includes set
if ( $?config_experiment ) exit 0
set config_experiment = 1

source config/scenario.csh

# getExperiment and setExperiment are helper functions that pick out individual
# configuration elements from within the "experiment" key of the scenario configuration
setenv getExperiment "$getConfig $baseConfig $scenarioConfig experiment"
setenv setExperiment "source $setConfig $baseConfig $scenarioConfig experiment"

##################################
## Fundamental experiment settings
##################################
$setExperiment ExpSuffix
$setExperiment MPASGridDescriptor
set preprocessObsList = (`$getExperiment preprocessObsList`)
set benchmarkObsList = (`$getExperiment benchmarkObsList`)
set hofxObsList = (`$getExperiment hofxObsList`)
$setExperiment DAType
set nInnerIterations = (`$getExperiment nInnerIterations`)

## nOuterIterations, automatically determined from length of nInnerIterations
setenv nOuterIterations ${#nInnerIterations}


#######################
## Variational settings
#######################
## variationalObsList
# observation types assimilated in variational application instances
# OPTIONS: see list below
# Abbreviations:
#   clr == clear-sky
#   cld == cloudy-sky
set l = ()
set l = ($l $benchmarkObsList)
#set l = ($l abi_g16)
#set l = ($l ahi_himawari8)
#set l = ($l abi-clr_g16)
#set l = ($l ahi-clr_himawari8)
# TODO: add scene-dependent ObsErrors to amsua-cld_* ObsSpaces
# TODO: combine amsua_* and amsua-cld_* similar to jedi-gdas
#set l = ($l amsua-cld_n19)
#set l = ($l amsua-cld_n18)
#set l = ($l amsua-cld_n15)
#set l = ($l amsua-cld_aqua)
#set l = ($l amsua-cld_metop-a)
#set l = ($l amsua-cld_metop-b)
set variationalObsList = ($l)

## MinimizerAlgorithm
# OPTIONS: DRIPCG, DRPLanczos, DRPBlockLanczos
# see classes derived from oops/src/oops/assimilation/Minimizer.h for all options
# Notes about DRPBlockLanczos:
# + still experimental, and not reliable for this experiment
# + only available when EDASize > 1
setenv BlockEDA DRPBlockLanczos
setenv MinimizerAlgorithm DRIPCG

if ( "$DAType" =~ *"eda"* ) then
  $setExperiment EDASize
  $setExperiment nDAInstances

  ## nEnsDAMembers
  # total number of ensemble DA members, product of EDASize and nDAInstances
  # Should be between 2 and $firstEnsFCNMembers, depends on data source in config/modeldata.csh
  @ nEnsDAMembers = $EDASize * $nDAInstances
  setenv nEnsDAMembers $nEnsDAMembers
else
  ## fixedEnsBType
  # selection of data source for fixed ensemble background covariance members
  # OPTIONS: GEFS (default), PreviousEDA
  setenv fixedEnsBType GEFS

  # tertiary settings for when fixedEnsBType is set to PreviousEDA
  setenv nPreviousEnsDAMembers 20
  setenv PreviousEDAForecastDir \
    /glade/scratch/guerrett/pandac/guerrett_eda_3denvar_NMEM${nPreviousEnsDAMembers}_RTPP0.80_LeaveOneOut_OIE120km_memberSpecificTemplate_GEFSSeaUpdate/CyclingFC

  # override settings for EDASize, nDAInstances, and nEnsDAMembers for non-eda setups
  # TODO: make DAType setting agnostic of eda_3denvar vs. 3denvar
  #       and use EDASize and nDAInstances instead
  setenv EDASize 1
  setenv nDAInstances 1
  @ nEnsDAMembers = $EDASize * $nDAInstances
  setenv nEnsDAMembers $nEnsDAMembers
endif

if ($EDASize == 1 && $MinimizerAlgorithm == $BlockEDA) then
  echo "WARNING: MinimizerAlgorithm cannot be $BlockEDA when EDASize is 1, re-setting to DRPLanczos"
  setenv MinimizerAlgorithm DRPLanczos
endif
$setExperiment LeaveOneOutEDA
$setExperiment RTPPInflationFactor
$setExperiment storeOriginalRTPPAnalyses
$setExperiment ABEInflation
$setExperiment ABEIChannel

##################################
## analysis and forecast intervals
##################################
#TODO: move these settings to scenario.workflow yaml section
setenv CyclingWindowHR 6                # forecast interval between CyclingDA analyses
setenv ExtendedFCWindowHR 240           # length of verification forecasts
setenv ExtendedFC_DT_HR 12              # interval between OMF verification times of an individual forecast
setenv ExtendedMeanFCTimes T00,T12      # times of the day to run extended forecast from mean analysis
setenv ExtendedEnsFCTimes T00           # times of the day to run ensemble of extended forecasts
setenv DAVFWindowHR ${CyclingWindowHR}  # window of observations included in AN/BG verification
setenv FCVFWindowHR 6                   # window of observations included in forecast verification
setenv forecastPrecision single         # floating-point precision of forecast output; options: [single, double]


########################
## experiment name parts
########################

## derive experiment title parts from above settings

#(1) ensemble-related settings
set ExpEnsSuffix = ''
if ($nEnsDAMembers > 1) then
  if ($EDASize > 1) then
    set ExpEnsSuffix = '_NMEM'${nDAInstances}x${EDASize}
    if ($MinimizerAlgorithm == $BlockEDA) then
      set ExpEnsSuffix = ${ExpEnsSuffix}Block
    endif
  else
    set ExpEnsSuffix = '_NMEM'${nEnsDAMembers}
  endif
  if (${RTPPInflationFactor} != "0.0") set ExpEnsSuffix = ${ExpEnsSuffix}_RTPP${RTPPInflationFactor}
  if (${LeaveOneOutEDA} == True) set ExpEnsSuffix = ${ExpEnsSuffix}_LeaveOneOut
  if (${ABEInflation} == True) set ExpEnsSuffix = ${ExpEnsSuffix}_ABEI_BT${ABEIChannel}
endif

#(2) observation selection
setenv ExpObsSuffix ''
foreach obs ($variationalObsList)
  set isBench = False
  foreach benchObs ($benchmarkObsList)
    if ("$obs" =~ *"$benchObs"*) then
      set isBench = True
    endif
  end
  if ( $isBench == False ) then
    setenv ExpObsSuffix ${ExpObsSuffix}_${obs}
  endif
end

#(3) inner iteration counts
set ExpIterSuffix = ''
foreach nInner ($nInnerIterations)
  set ExpIterSuffix = ${ExpIterSuffix}-${nInner}
end
if ( $nOuterIterations > 0 ) then
  set ExpIterSuffix = ${ExpIterSuffix}-iter
endif
