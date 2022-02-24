#!/bin/csh -f

# only load experiment if it is not already loaded
# note: set must be used instead of setenv, because some of the setExperiment commands apply to
# lists, which use set instead of setenv
if ( $?config_experiment ) exit 0
set config_experiment = 1

source config/scenario.csh

# setExperiment is a helper function that picks out a configuration node
# under the "experiment" key of scenarioConfig
setenv setExperiment "source $setConfig $baseConfig $scenarioConfig experiment"

##################################
## Fundamental experiment settings
##################################

## from scenarioConfig
$setExperiment ExpSuffix
$setExperiment MPASGridDescriptor
$setExperiment preprocessObsList
$setExperiment benchmarkObsList
$setExperiment hofxObsList
$setExperiment DAType
$setExperiment nInnerIterations

# deterministic settings
$setExperiment fixedEnsBType
$setExperiment nPreviousEnsDAMembers
$setExperiment PreviousEDAForecastDir

# stochastic settings
$setExperiment EDASize
$setExperiment nDAInstances
$setExperiment LeaveOneOutEDA
$setExperiment RTPPInflationFactor
$setExperiment storeOriginalRTPPAnalyses

# ensemble inflation settings
$setExperiment ABEInflation
$setExperiment ABEIChannel

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
  # placeholder for now
else
  # override settings for EDASize, nDAInstances, and nEnsDAMembers for non-eda setups
  # TODO: make DAType setting agnostic of eda_3denvar vs. 3denvar
  #       and use EDASize and nDAInstances instead
  setenv EDASize 1
  setenv nDAInstances 1
endif
## nEnsDAMembers
# total number of ensemble DA members, product of EDASize and nDAInstances
# Should be in range (1, $firstEnsFCNMembers), depends on data source in config/modeldata.csh
@ nEnsDAMembers = $EDASize * $nDAInstances
setenv nEnsDAMembers $nEnsDAMembers

if ($EDASize == 1 && $MinimizerAlgorithm == $BlockEDA) then
  echo "WARNING: MinimizerAlgorithm cannot be $BlockEDA when EDASize is 1, re-setting to DRPLanczos"
  setenv MinimizerAlgorithm DRPLanczos
endif

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

$setExperiment ExperimentName
