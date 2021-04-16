#!/bin/csh -f

source config/experiment.csh
source config/filestructure.csh
source config/tools.csh
source config/mpas/${MPASGridDescriptor}/mesh.csh


####################
## static data files
####################
## common directories
set PANDACCommonData = /glade/p/mmm/parc/liuz/pandac_common
set GFSAnaDirOuter = ${PANDACCommonData}/${MPASGridDescriptorOuter}_GFSANA
set GFSAnaDirInner = ${PANDACCommonData}/${MPASGridDescriptorInner}_GFSANA
set GFSAnaDirEnsemble = ${PANDACCommonData}/${MPASGridDescriptorEnsemble}_GFSANA

set GEFSAnaDir = /glade/p/mmm/parc/guerrett/pandac/fixed_input

## date from which first background is initialized
set prevFirstCycleDate = `$advanceCYMDH ${FirstCycleDate} -${CyclingWindowHR}`
set yy = `echo ${prevFirstCycleDate} | cut -c 1-4`
set mm = `echo ${prevFirstCycleDate} | cut -c 5-6`
set dd = `echo ${prevFirstCycleDate} | cut -c 7-8`
set hh = `echo ${prevFirstCycleDate} | cut -c 9-10`
set prevFirstFileDate = ${yy}-${mm}-${dd}_${hh}.00.00

# externally sourced model states
# -------------------------------
## deterministic - GFS
setenv GFS6hfcFORFirstCycle ${PANDACCommonData}/${MPASGridDescriptorOuter}_1stCycle_background/${prevFirstCycleDate}

# first cycle background state
setenv firstDetermFCDir ${GFS6hfcFORFirstCycle}

## stochastic - GEFS
set gefsMemFmt = "/{:02d}"
set nGEFSMembers = 20
set GEFS6hfcFOREnsBDir = ${PANDACCommonData}/${MPASGridDescriptorEnsemble}_EnsFC
set GEFS6hfcFOREnsBFilePrefix = EnsForCov
set GEFS6hfcFORFirstCycle = ${GEFSAnaDir}/${MPASGridDescriptorEnsemble}/${MPASGridDescriptorEnsemble}EnsFCFirstCycle/${prevFirstCycleDate}

# first cycle background states
setenv firstEnsFCNMembers 80
setenv firstEnsFCDir ${GEFS6hfcFORFirstCycle}
if ( $nEnsDAMembers > $firstEnsFCNMembers ) then
  echo "WARNING: nEnsDAMembers must be <= nFixedMembers, changing ensemble size"
  setenv nEnsDAMembers ${nFixedMembers}
endif


if ( "$DAType" =~ *"eda"* ) then
  setenv firstFCMemFmt "${gefsMemFmt}"
  setenv firstFCDir ${firstEnsFCDir}
  set firstFCFilePrefix = ${FCFilePrefix}
else
  setenv firstFCMemFmt " "
  setenv firstFCDir ${firstDetermFCDir}

  # TODO: re-generate GFS forecasts from 'da_state' stream with FCFilePrefix
  set firstFCFilePrefix = ${RSTFilePrefix}
endif

# background covariance
# ---------------------
## stochastic analysis (dynamic directory structure)
set dynamicEnsBMemFmt = "${flowMemFmt}"
set dynamicEnsBFilePrefix = ${FCFilePrefix}

## select the ensPb settings based on DAType
if ( "$DAType" =~ *"eda"* ) then
  set dynamicEnsBNMembers = ${nEnsDAMembers}
  set dynamicEnsBDir = ${CyclingFCWorkDir}

  setenv ensPbDir ${dynamicEnsBDir}
  setenv ensPbFilePrefix ${dynamicEnsBFilePrefix}
  setenv ensPbMemFmt "${dynamicEnsBMemFmt}"
  setenv ensPbNMembers ${dynamicEnsBNMembers}
else
  ## deterministic analysis (static directory structure)
  # parse selections
  if ("$fixedEnsBType" == "GEFS") then
    set fixedEnsBMemFmt = "${gefsMemFmt}"
    set fixedEnsBNMembers = ${nGEFSMembers}
    set fixedEnsBDir = ${GEFS6hfcFOREnsBDir}
    set fixedEnsBFilePrefix = ${GEFS6hfcFOREnsBFilePrefix}
  else if ("$fixedEnsBType" == "PreviousEDA") then
    set fixedEnsBMemFmt = "${dynamicEnsBMemFmt}"
    set fixedEnsBNMembers = ${nPreviousEnsDAMembers}
    set fixedEnsBDir = ${PreviousEDAForecastDir}
    set fixedEnsBFilePrefix = ${dynamicEnsBFilePrefix}
  else
    echo "ERROR in $0 : unrecognized value for fixedEnsBType --> ${fixedEnsBType}" >> ./FAIL
    exit 1
  endif

  setenv ensPbDir ${fixedEnsBDir}
  setenv ensPbFilePrefix ${fixedEnsBFilePrefix}
  setenv ensPbMemFmt "${fixedEnsBMemFmt}"
  setenv ensPbNMembers ${fixedEnsBNMembers}
endif


# MPAS-Model
# ----------
## directory containing x1.${MPASnCells}.graph.info* files
setenv GraphInfoDir /glade/work/duda/static_moved_to_campaign

## sea/ocean surface files
setenv updateSea 1
#if ( "$DAType" =~ *"eda"* ) then
# TODO: process sst/xice data for all GEFS members at all cycle/forecast dates
#  # stochastic
#  setenv SeaAnaDir ${GEFSAnaDir}/${MPASGridDescriptorOuter}/GEFS/init/000hr
#  setenv seaMemFmt "${gefsMemFmt}"
#  setenv SeaFilePrefix ${InitFilePrefix}
#else
  # deterministic
  setenv SeaAnaDir ${GFSAnaDirOuter}
  setenv seaMemFmt " "
  setenv SeaFilePrefix x1.${MPASnCellsOuter}.sfc_update
#endif

## static stream data
if ( "$DAType" =~ *"eda"* ) then
  # stochastic
  setenv StaticFieldsDirOuter ${GEFSAnaDir}/${MPASGridDescriptorOuter}/GEFS/init/000hr/${prevFirstCycleDate}
  setenv StaticFieldsDirInner ${GEFSAnaDir}/${MPASGridDescriptorInner}/GEFS/init/000hr/${prevFirstCycleDate}
  setenv StaticFieldsDirEnsemble ${GEFSAnaDir}/${MPASGridDescriptorEnsemble}/GEFS/init/000hr/${prevFirstCycleDate}
  setenv staticMemFmt "${gefsMemFmt}"
else
  # deterministic
  setenv StaticFieldsDirOuter ${GFSAnaDirOuter}/${prevFirstCycleDate}
  setenv StaticFieldsDirInner ${GFSAnaDirInner}/${prevFirstCycleDate}
  setenv StaticFieldsDirEnsemble ${GFSAnaDirEnsemble}/${prevFirstCycleDate}
  setenv staticMemFmt " "
endif
setenv StaticFieldsFileOuter ${InitFilePrefixOuter}.${prevFirstFileDate}.nc
setenv StaticFieldsFileInner ${InitFilePrefixInner}.${prevFirstFileDate}.nc
setenv StaticFieldsFileEnsemble ${InitFilePrefixEnsemble}.${prevFirstFileDate}.nc
