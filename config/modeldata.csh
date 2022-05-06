#!/bin/csh -f

if ( $?config_modeldata ) exit 0
set config_modeldata = 1

source config/workflow.csh
source config/model.csh
source config/experiment.csh
set wd = `pwd`
source config/tools.csh $wd
source config/${InitializationType}ModelData.csh

## file date for first background
set yy = `echo ${FirstCycleDate} | cut -c 1-4`
set mm = `echo ${FirstCycleDate} | cut -c 5-6`
set dd = `echo ${FirstCycleDate} | cut -c 7-8`
set hh = `echo ${FirstCycleDate} | cut -c 9-10`
setenv FirstFileDate ${yy}-${mm}-${dd}_${hh}.00.00

## next date from which first background is initialized
set nextFirstCycleDate = `$advanceCYMDH ${FirstCycleDate} +${CyclingWindowHR}`
setenv nextFirstCycleDate ${nextFirstCycleDate}
set Nyy = `echo ${nextFirstCycleDate} | cut -c 1-4`
set Nmm = `echo ${nextFirstCycleDate} | cut -c 5-6`
set Ndd = `echo ${nextFirstCycleDate} | cut -c 7-8`
set Nhh = `echo ${nextFirstCycleDate} | cut -c 9-10`
set nextFirstFileDate = ${Nyy}-${Nmm}-${Ndd}_${Nhh}.00.00

# externally sourced model states
# -------------------------------
## deterministic - GFS
setenv GFS6hfcFORFirstCycleOuter ${OuterModelData}/SingleFCFirstCycle/${FirstCycleDate}
setenv GFS6hfcFORFirstCycleInner ${InnerModelData}/SingleFCFirstCycle/${FirstCycleDate}

# first cycle background state
setenv firstDetermFCDirOuter ${GFS6hfcFORFirstCycleOuter}
setenv firstDetermFCDirInner ${GFS6hfcFORFirstCycleInner}

## stochastic - GEFS
set gefsMemPrefix = "None"
set gefsMemNDigits = 2
set gefsMemFmt = "/{:0${gefsMemNDigits}d}"
set nGEFSMembers = 20
set GEFS6hfcFOREnsBDir = ${EnsembleModelData}/EnsForCov
set GEFS6hfcFOREnsBFilePrefix = EnsForCov
set GEFS6hfcFORFirstCycle = ${EnsembleModelData}/EnsFCFirstCycle/${FirstCycleDate}

# first cycle background states
# TODO: determine firstEnsFCNMembers from source data
setenv firstEnsFCNMembers 80
setenv firstEnsFCDir ${GEFS6hfcFORFirstCycle}
if ( $nMembers > $firstEnsFCNMembers ) then
  echo "WARNING: nMembers must be <= firstEnsFCNMembers, changing ensemble size"
  setenv nMembers ${firstEnsFCNMembers}
endif


if ( $nMembers > 1 ) then
  setenv firstFCMemFmt "${gefsMemFmt}"
  setenv firstFCDirOuter ${firstEnsFCDir}
  setenv firstFCDirInner ${firstEnsFCDir}
  setenv firstFCFilePrefix ${FCFilePrefix}
else
  setenv firstFCMemFmt " "
  setenv firstFCDirOuter ${firstDetermFCDirOuter}
  setenv firstFCDirInner ${firstDetermFCDirInner}
  setenv firstFCFilePrefix ${FCFilePrefix}
endif

# background covariance
# ---------------------
## stochastic analysis (dynamic directory structure, depends on $nMembers)
set dynamicEnsBMemPrefix = "${flowMemPrefix}"
set dynamicEnsBMemNDigits = ${flowMemNDigits}
set dynamicEnsBFilePrefix = ${FCFilePrefix}

## select the ensPb settings based on nMembers
if ( $nMembers > 1 ) then
  setenv ensPbMemPrefix ${dynamicEnsBMemPrefix}
  setenv ensPbMemNDigits ${dynamicEnsBMemNDigits}
  setenv ensPbFilePrefix ${dynamicEnsBFilePrefix}

  setenv ensPbDir ${CyclingFCWorkDir}
  setenv ensPbNMembers ${nMembers}
else
  ## deterministic analysis (static directory structure)
  # parse selections
  if ("$fixedEnsBSource" == "GEFS") then
    set ensPbMemPrefix = "${gefsMemPrefix}"
    set ensPbMemNDigits = ${gefsMemNDigits}
    set ensPbFilePrefix = ${GEFS6hfcFOREnsBFilePrefix}

    set ensPbDir = ${GEFS6hfcFOREnsBDir}
    set ensPbNMembers = ${nGEFSMembers}
  else if ("$fixedEnsBSource" == "PreviousEDA") then
    set ensPbMemPrefix = "${dynamicEnsBMemPrefix}"
    set ensPbMemNDigits = ${dynamicEnsBMemNDigits}
    set ensPbFilePrefix = ${dynamicEnsBFilePrefix}

    set ensPbDir = ${PreviousEDAForecastDir}
    set ensPbNMembers = ${nPreviousEnsDAMembers}
  else
    echo "ERROR in $0 : unrecognized value for fixedEnsBSource --> ${fixedEnsBSource}" >> ./FAIL
    exit 1
  endif
endif


# MPAS-Model
# ----------
## sea/ocean surface files
setenv seaMaxMembers ${nGEFSMembers}
setenv deterministicSeaAnaDir ${GFSAnaDirOuter}
if ( $nMembers > 1 ) then
  # using member-specific sst/xice data from GEFS
  # 60km and 120km
  setenv SeaAnaDir /glade/p/mmm/parc/guerrett/pandac/fixed_input/GEFS/surface/000hr/${model__precision}
  setenv seaMemFmt "${gefsMemFmt}"
else
  # deterministic
  # 60km and 120km
  setenv SeaAnaDir ${deterministicSeaAnaDir}
  setenv seaMemFmt " "
endif

## static stream data
if ( $nMembers > 1 ) then
  # stochastic
  # 60km and 120km
  setenv StaticFieldsDirOuter /glade/p/mmm/parc/guerrett/pandac/fixed_input/GEFS/init/000hr/${FirstCycleDate}
  setenv StaticFieldsDirInner /glade/p/mmm/parc/guerrett/pandac/fixed_input/GEFS/init/000hr/${FirstCycleDate}
  setenv StaticFieldsDirEnsemble /glade/p/mmm/parc/guerrett/pandac/fixed_input/GEFS/init/000hr/${FirstCycleDate}
  setenv staticMemFmt "${gefsMemFmt}"
else
  # deterministic
  # 30km, 60km, and 120km
  setenv StaticFieldsDirEnsemble ${GFSAnaDirEnsemble}
  setenv staticMemFmt " "
endif
setenv StaticFieldsFileOuter ${InitFilePrefixOuter}.${FirstFileDate}.nc
setenv StaticFieldsFileInner ${InitFilePrefixInner}.${FirstFileDate}.nc
setenv StaticFieldsFileEnsemble ${InitFilePrefixEnsemble}.${FirstFileDate}.nc
