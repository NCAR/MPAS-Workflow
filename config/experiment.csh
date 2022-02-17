#!/bin/csh -f

####################
# workflow controls
####################
## FirstCycleDate
# initial date of this experiment
# OPTIONS:
#   + 2018041500
#   + 2020072300 --> experimental
#     - TODO: standardize GFS and observation source data
#     - TODO: enable QC
#     - TODO: enable VarBC
setenv FirstCycleDate 2018041418

## InitializationType
# Indicates the type of initialization at the initial cycle: cold or warm start
# OPTIONS:
#   ColdStart - generate first forecast online from an external GFS analysis
#   WarmStart - copy a pre-generated forecast
setenv InitializationType WarmStart

## PreprocessObs
# Whether to convert RDA archived BUFR observations to IODA on the fly (True)
# or use pre-converted observation files, the latter only being available for
# specific time periods
# OPTIONS: True/False
setenv PreprocessObs False


##################################
## Fundamental experiment settings
##################################
## MPASGridDescriptor
# used to distinguish betwen MPAS meshes across experiments
# O = variational Outer loop, forecast, HofX
# I = variational Inner loop
# E = variational Ensemble
# OPTIONS:
#   + OIE120km -- 3dvar, 3denvar, eda_3denvar
#   + O30kmIE120km -- dual-resolution 3denvar
#   + OIE60km -- eda_3denvar only
#   + TODO: OIE60km -- 3denvar, requires generating MPASSeaVariables update files from GFS analyses
#   + O30kmIE60km -- dual-resolution 3denvar
#   + TODO: "OIE30km" 3denvar
#   + TODO: "O30kmIE60km" dual-resolution eda_3denvar with 60km ensemble, 30km deterministic
#   + TODO: "OE30kmI60km" dual-resolution eda_3denvar with 30km ensemble, no deterministic?
#   + TODO: "OIE120km" 4denvar
#   + TODO: "OIE60km" 4denvar
#   + TODO: "O30kmIE60km" dual-resolution 4denvar
setenv MPASGridDescriptor OIE120km

## benchmarkObsList
# base set of observation types assimilated in all experiments
set l = ()
set l = ($l sondes)
set l = ($l aircraft)
set l = ($l satwind)
set l = ($l satwnd)
set l = ($l gnssroref)
set l = ($l sfc)
set l = ($l amsua_n19)
set l = ($l amsua_n18)
set l = ($l amsua_n15)
set l = ($l amsua_aqua)
set l = ($l amsua_metop-a)
set l = ($l amsua_metop-b)
set benchmarkObsList = ($l)

## list of observations to convert to IODA
set l = ()
set l = ($l prepbufr)
set l = ($l satwnd)
set l = ($l gpsro)
set l = ($l 1bamua)
#set l = ($l 1bmhs)
#set l = ($l airsev)
#set l = ($l cris)
#set l = ($l mtiasi)
set preprocessObsList = ($l)

## ExpSuffix
# a unique suffix to distinguish this experiment from others
set ExpSuffix = ''

##############
## DA settings
##############
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

## DAType
# OPTIONS: 3dvar, 3denvar, eda_3denvar
# Note: 3dvar currently only works for OIE120km
setenv DAType 3dvar

## nInnerIterations
# list of inner iteration counts across all outer iterations
set nInnerIterations = (60)

## MinimizerAlgorithm
# OPTIONS: DRIPCG, DRPLanczos, DRPBlockLanczos
# see classes derived from oops/src/oops/assimilation/Minimizer.h for all options
# Notes about DRPBlockLanczos:
# + still experimental, and not reliable for this experiment
# + only available when EDASize > 1
setenv BlockEDA DRPBlockLanczos
setenv MinimizerAlgorithm DRIPCG

if ( "$DAType" =~ *"eda"* ) then
  ## EDASize
  # ensemble size of each DA instance
  # OPTIONS:
  #   1: ensemble of nDAInstances independent Variational applications (nEnsDAMembers jobs), each
  #      with 1 background state member per DA job
  # > 1: ensemble of nDAInstances independent EnsembleOfVariational applications, each with EDASize
  #      background state members per DA job
  # In both cases, nEnsDAMembers forecasts are used for the flow-dependent background error
  setenv EDASize 1

  ## nDAInstances
  setenv nDAInstances 20

  ## nEnsDAMembers
  # total number of ensemble DA members, product of EDASize and nDAInstances
  # Should be between 2 and $firstEnsFCNMembers, depends on data source in config/modeldata.csh
  @ nEnsDAMembers = $EDASize * $nDAInstances
else
  ## fixedEnsBType
  # selection of data source for fixed ensemble background covariance members
  # OPTIONS: GEFS (default), PreviousEDA
  set fixedEnsBType = GEFS

  # tertiary settings for when fixedEnsBType is set to PreviousEDA
  set nPreviousEnsDAMembers = 20
  set PreviousEDAForecastDir = \
    /glade/scratch/guerrett/pandac/guerrett_eda_3denvar_NMEM${nPreviousEnsDAMembers}_RTPP0.80_LeaveOneOut_OIE120km_memberSpecificTemplate_GEFSSeaUpdate/CyclingFC

  # override settings for EDASize, nDAInstances, and nEnsDAMembers for non-eda setups
  # TODO: make DAType setting agnostic of eda_3denvar vs. 3denvar
  #       and use EDASize and nDAInstances instead
  setenv EDASize 1
  setenv nDAInstances 1
  @ nEnsDAMembers = $EDASize * $nDAInstances
endif

if ($EDASize == 1 && $MinimizerAlgorithm == $BlockEDA) then
  echo "WARNING: MinimizerAlgorithm cannot be $BlockEDA when EDASize is 1, re-setting to DRPLanczos"
  setenv MinimizerAlgorithm DRPLanczos
endif

## LeaveOneOutEDA, whether to use self-exclusion in the EnVar ensemble B during EDA cycling
# OPTIONS: True/False
setenv LeaveOneOutEDA True

## RTPPInflationFactor, relaxation parameter for the relaxation to prior perturbation (RTPP) inflation mechanism
# Typical Values: 0.0 or 0.50 to 0.90
setenv RTPPInflationFactor 0.80

## storeOriginalRTPPAnalyses, whether to store the analyses taken as inputs to RTPP for diagnostic purposes
# OPTIONS: True/False
setenv storeOriginalRTPPAnalyses False

## ABEIInflation, whether to utilize adaptive background error inflation (ABEI) in cloud-affected scenes
#  as measured by ABI and AHI observations
# OPTIONS: True/False
setenv ABEInflation False

## ABEIChannel
# OPTIONS: 8, 9, 10
setenv ABEIChannel 8

################
## HofX settings
################
## hofxObsList
# observation types simulated in hofx application instances for verification
# OPTIONS: see list below
# Abbreviations:
#   clr == clear-sky
#   cld == cloudy-sky
set l = ()
set l = ($l sondes)
set l = ($l aircraft)
set l = ($l satwind)
set l = ($l satwnd)
set l = ($l gnssroref)
set l = ($l sfc)
set l = ($l amsua_n19)
set l = ($l amsua_n18)
set l = ($l amsua_n15)
set l = ($l amsua_aqua)
set l = ($l amsua_metop-a)
set l = ($l amsua_metop-b)
set l = ($l amsua-cld_n19)
set l = ($l amsua-cld_n18)
set l = ($l amsua-cld_n15)
set l = ($l amsua-cld_aqua)
set l = ($l amsua-cld_metop-a)
set l = ($l amsua-cld_metop-b)
set l = ($l mhs_n19)
set l = ($l mhs_n18)
set l = ($l mhs_metop-a)
set l = ($l mhs_metop-b)
set l = ($l abi_g16)
set l = ($l ahi_himawari8)
#set l = ($l abi-clr_g16)
#set l = ($l ahi-clr_himawari8)
set hofxObsList = ($l)


#GEFS reference case (override above settings)
#====================================================
#set ExpSuffix = _GEFSVerify
#setenv DAType eda_3denvar
#setenv EDASize 1
#setenv nDAInstances 20
#setenv nEnsDAMembers 20
#setenv RTPPInflationFactor 0.0
#setenv LeaveOneOutEDA False
#set variationalObsList = ($benchmarkObsList)
#set nInnerIterations = ()
#====================================================

## nOuterIterations, automatically determined from length of nInnerIterations
setenv nOuterIterations ${#nInnerIterations}

##################################
## analysis and forecast intervals
##################################
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
