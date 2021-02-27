#!/bin/csh -f

source config/appindex.csh
source config/experiment.csh
source config/mpas/${MPASGridDescriptor}-mesh.csh

#######################################
## state file and directory descriptors
#######################################
setenv RSTFilePrefix   restart
setenv ICFilePrefix    mpasin
setenv InitFilePrefix x1.${MPASnCells}.init

setenv FCFilePrefix    mpasout
setenv fcDir           fc
setenv DIAGFilePrefix  diag

setenv ANFilePrefix    an
setenv anDir           ${ANFilePrefix}
setenv BGFilePrefix    bg
setenv bgDir           ${BGFilePrefix}

setenv TemplateFilePrefix templateFields
setenv localStaticFieldsFile static.nc

setenv OrigFileSuffix  _orig

## directory string formatter for EDA members
# third argument to memberDir.py
setenv flowMemFmt "/mem{:03d}"

##########################
## static data directories
##########################
setenv STATICUSER       guerrett
setenv TOP_STATIC_DIR   /glade/work/${STATICUSER}/pandac
setenv FIXED_INPUT      ${TOP_STATIC_DIR}/fixed_input
setenv PANDACCommonData /glade/p/mmm/parc/liuz/pandac_common


#####################
## Verification tools
#####################
#TODO: add these to the repo, possibly under a verification directory
#setenv pyObsDir          ${FIXED_INPUT}/graphics_obs
setenv pyObsDir          ${FIXED_INPUT}/graphics_obs_abei
setenv pyModelDir        ${FIXED_INPUT}/graphics_model

## database file prefixes
#  for obs, geovals, and hofx-diagnostics
# Note: these are self-consistent across multiple applications
#       and can be changed to any non-empty string
setenv obsPrefix      obsout
setenv geoPrefix      geoval
setenv diagPrefix     ydiags

## InDBDir and OutDBDir control the names of the database directories
# on input and output from jedi applications
setenv InDBDir  dbIn
setenv OutDBDir dbOut


####################
## static data files
####################

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
#setenv GFS6hfcFORFirstCycle  /glade/work/liuz/pandac/fix_input/${MPASGridDescriptor}_1stCycle_background/${prevFirstCycleDate} --> deprecate soon 25-Feb-2021
setenv GFS6hfcFORFirstCycle ${PANDACCommonData}/${MPASGridDescriptor}_1stCycle_background/${prevFirstCycleDate}
setenv GFSAnaDir ${PANDACCommonData}/${MPASGridDescriptor}_GFSANA

# first cycle background state
setenv firstDetermFCDir ${GFS6hfcFORFirstCycle}

## stochastic - GEFS
set gefsMemFmt = "/{:02d}"
set nGEFSMembers = 20
set GEFS6hfcFOREnsBDir = ${PANDACCommonData}/${MPASEnsembleGridDescriptor}_EnsFC
set GEFS6hfcFOREnsBFilePrefix = EnsForCov
set GEFSAnaDir = /glade/p/mmm/parc/guerrett/pandac/fixed_input/${MPASEnsembleGridDescriptor}
set GEFS6hfcFORFirstCycle = ${GEFSAnaDir}/${MPASEnsembleGridDescriptor}EnsFCFirstCycle/${prevFirstCycleDate}

# first cycle background states
setenv firstEnsFCMemFmt "${gefsMemFmt}"
setenv firstEnsFCNMembers 80
setenv firstEnsFCDir ${GEFS6hfcFORFirstCycle}
if ( $nEnsDAMembers > $firstEnsFCNMembers ) then
  echo "WARNING: nEnsDAMembers must be <= nFixedMembers, changing ensemble size"
  setenv nEnsDAMembers ${nFixedMembers}
endif


# background covariance
# ---------------------
## deterministic (static)
setenv fixedEnsBMemFmt "${gefsMemFmt}"
setenv fixedEnsBNMembers ${nGEFSMembers}
setenv fixedEnsBDir ${GEFS6hfcFOREnsBDir}
setenv fixedEnsBFilePrefix ${GEFS6hfcFOREnsBFilePrefix}

## stochastic (dynamic)
setenv dynamicEnsBMemFmt "${flowMemFmt}"
setenv dynamicEnsBNMembers ${nEnsDAMembers}
setenv dynamicEnsBDir ${CyclingFCWorkDir}
setenv dynamicEnsBFilePrefix ${FCFilePrefix}


# MPAS-Model
# ----------
## directory containing x1.${MPASnCells}.graph.info* files
setenv GraphInfoDir /glade/work/duda/static_moved_to_campaign

## sea/ocean surface files
setenv updateSea 1
#if ( "$DAType" =~ *"eda"* ) then
# TODO: process sst/xice data for all GEFS members at all cycle/forecast dates
#  # stochastic
#  setenv SeaAnaDir ${GEFSAnaDir}/GEFS/init/000hr
#  setenv seaMemFmt "${gefsMemFmt}"
#  setenv SeaFilePrefix ${InitFilePrefix}
#else
  # deterministic
  setenv SeaAnaDir ${GFSAnaDir}
  setenv seaMemFmt " "
  setenv SeaFilePrefix x1.${MPASnCells}.sfc_update
#endif

## static.nc source data
if ( "$DAType" =~ *"eda"* ) then
  # stochastic
  setenv staticFieldsDir ${GEFSAnaDir}/GEFS/init/000hr/${prevFirstCycleDate}
  setenv staticMemFmt "${gefsMemFmt}"
  setenv staticFieldsFile ${InitFilePrefix}.${prevFirstFileDate}.nc
else
  # deterministic
  setenv staticFieldsDir ${GFSAnaDir}/${prevFirstCycleDate}
  setenv staticMemFmt " "
  setenv staticFieldsFile ${InitFilePrefix}.${prevFirstFileDate}.nc
endif


# MPAS-JEDI
# ----------
## appyaml: universal yaml file name for all jedi applications
setenv appyaml jedi.yaml

## Background Error
# Last updated 08 Feb 2021
# works for 36pe/128pe and 120km domain
#setenv bumpLocDir ${FIXED_INPUT}/${MPASEnsembleGridDescriptor}/bumploc_${CyclingDAPEPerMember}pe_20210208
setenv bumpLocDir /glade/scratch/bjung/x_bumploc_20210208
setenv bumpLocPrefix bumploc_2000_5

## Observations
setenv CONVObsDir ${TOP_STATIC_DIR}/obs/conv

# Polar MW (amsua, mhs)
# bias correction
set MWNoBias = no_bias
set MWGSIBC = bias_corr
setenv MWBiasCorrect $MWGSIBC

# directories
set baseMWObsDir = /glade/p/mmm/parc/vahl/gsi_ioda/
set MWObsDir = ()
foreach application (${applicationIndex})
  set MWObsDir = ($MWObsDir \
    ${baseMWObsDir} \
  )
end
set MWObsDir[$variationalIndex] = $MWObsDir[$variationalIndex]$MWBiasCorrect

# no bias correction for hofx
set MWObsDir[$hofxIndex] = $MWObsDir[$hofxIndex]$MWNoBias

# Geostationary IR (abi, ahi)
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
set baseABIObsDir = ${TOP_STATIC_DIR}/obs/ABIASR/IODANC_THIN15KM_SUPEROB
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
set baseAHIObsDir = ${TOP_STATIC_DIR}/obs/AHIASR/IODANC_SUPEROB
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

# CRTM
# ----
setenv CRTMTABLES ${FIXED_INPUT}/crtm_bin/

# VARBC
# -----
setenv INITIAL_VARBC_TABLE ${FIXED_INPUT}/satbias/satbias_crtm_in
setenv VARBC_ANA ${OutDBDir}/satbias_crtm_ana

