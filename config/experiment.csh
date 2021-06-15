#!/bin/csh -f

source config/appindex.csh

##################################
## Fundamental experiment settings
##################################
## MPASGridDescriptor
# used to distinguish betwen MPAS meshes across experiments
# O = variational Outer loop, forecast, HofX
# I = variational Inner loop
# E = variational Ensemble
# OPTIONS:
#   + OIE120km 3denvar
#   + OIE120km eda_3denvar
#   + TODO: "OIE30km" 3denvar
#   + TODO: "O30kmIE120km" dual-resolution 3denvar
#   + TODO: "O30kmIE120km" dual-resolution eda_3denvar
#   + TODO: "OIE120km" 4denvar
#   + TODO: "O30kmIE120km" dual-resolution 4denvar
setenv MPASGridDescriptor OIE120km

## FirstCycleDate
# initial date of this experiment
# OPTIONS:
#   + 2018041500
#   + 2020072300 --> experimental
#     - TODO: standardize GFS and observation source data
#     - TODO: enable QC
#     - TODO: enable VarBC
setenv FirstCycleDate 2018041500

## benchmarkObsList
# base set of observation types assimilated in all experiments
set benchmarkObsList = (sondes aircraft satwind gnssroref sfcp clramsua)

## ExpSuffix
# a unique suffix to distinguish this experiment from others
set ExpSuffix = ''

##############
## DA settings
##############
# add IR super-obbing resolution suffixes for variational
set abi = abi$ABISuperOb[$variationalIndex]
set ahi = ahi$AHISuperOb[$variationalIndex]

## variationalObsList
# observation types assimilated in all variational application instances
# OPTIONS: $benchmarkObsList, cldamsua, clr$abi, all$abi, clr$ahi, all$ahi
# clr == clear-sky
# cld == cloudy-sky
# all == all-sky
#TODO: separate amsua and mhs config for each instrument_satellite combo

set variationalObsList = ($benchmarkObsList)
#set variationalObsList = ($benchmarkObsList cldamsua)
#set variationalObsList = ($benchmarkObsList all$abi)
#set variationalObsList = ($benchmarkObsList all$ahi)
#set variationalObsList = ($benchmarkObsList all$abi all$ahi)

## DAType
# OPTIONS: 3denvar, eda_3denvar, 3dvarId
setenv DAType eda_3denvar

if ( "$DAType" =~ *"eda"* ) then
  ## nEnsDAMembers
  # OPTIONS: 2 to $firstEnsFCNMembers, depends on data source in config/modeldata.csh
  setenv nEnsDAMembers 20
else
  setenv nEnsDAMembers 1

  ## fixedEnsBType
  # selection of data source for fixed ensemble background covariance members
  # OPTIONS: GEFS (default), PreviousEDA
  set fixedEnsBType = GEFS

  # tertiary settings for when fixedEnsBType is set to PreviousEDA
  set nPreviousEnsDAMembers = 20
  set PreviousEDAForecastDir = \
    /glade/scratch/guerrett/pandac/guerrett_eda_3denvar_NMEM${nPreviousEnsDAMembers}_LeaveOneOut_OIE120km/CyclingFC
endif

## LeaveOneOutEDA
# OPTIONS: True/False
setenv LeaveOneOutEDA True

## RTPPInflationFactor
# Typical Values: 0.0 or 0.50 to 0.90
setenv RTPPInflationFactor 0.0

## ABEIInflation
# OPTIONS: True/False
setenv ABEInflation False

## ABEIChannel
# OPTIONS: 8, 9, 10
setenv ABEIChannel 8

################
## HofX settings
################
# add IR super-obbing resolution suffixes for hofx
set abi = abi$ABISuperOb[$hofxIndex]
set ahi = ahi$AHISuperOb[$hofxIndex]

## hofxObsList
# observation types simulated in all hofx application instances
# OPTIONS: $benchmarkObsList, cldamsua, allmhs, clr$abi, all$abi, clr$ahi, all$ahi
#TODO: separate amsua and mhs config for each instrument_satellite combo

#TODO: upgrade abi and ahi data
set hofxObsList = ($benchmarkObsList cldamsua allmhs all$abi all$ahi)


#GEFS reference case (override above settings)
#====================================================
#set ExpSuffix = _GEFSVerify
#setenv DAType eda_3denvar
#setenv nEnsDAMembers 20
#setenv RTPPInflationFactor 0.0
#setenv LeaveOneOutEDA False
#set variationalObsList = ($benchmarkObsList)
#====================================================

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


########################
## experiment name parts
########################

## derive experiment title parts from above settings

#(1) populate ensemble-related suffix components
set EnsExpSuffix = ''
if ($nEnsDAMembers > 1) then
  set EnsExpSuffix = '_NMEM'${nEnsDAMembers}
  if (${RTPPInflationFactor} != "0.0") set EnsExpSuffix = ${EnsExpSuffix}_RTPP${RTPPInflationFactor}
  if (${LeaveOneOutEDA} == True) set EnsExpSuffix = ${EnsExpSuffix}_LeaveOneOut
  if (${ABEInflation} == True) set EnsExpSuffix = ${EnsExpSuffix}_ABEI_BT${ABEIChannel}
endif

#(2) add observation selection info
setenv ExpObsName ''
foreach obs ($variationalObsList)
  set isBench = False
  foreach benchObs ($benchmarkObsList)
    if ("$obs" =~ *"$benchObs"*) then
      set isBench = True
    endif
  end
  if ( $isBench == False ) then
    setenv ExpObsName ${ExpObsName}_${obs}
  endif
end
