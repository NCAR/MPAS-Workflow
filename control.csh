#!/bin/csh -f

## FirstCycleDate
# used to initiate new experiments
setenv FirstCycleDate 2018041500

# TODO: split up control.csh so that $advanceCYMDH can be executed properly
#       prevFirstCycleDate is temporarily hard-coded here
#       Search prevFirstCycleDate below for context
set prevFirstCycleDate = 2018041418

## base set of observation types assimilated in all experiments
set defaultObsList = (sondes aircraft satwind gnssroref sfcp clramsua)

## application indices allowing re-use of common components for similar applications
set applicationIndex = ( da omm )
set applicationObsIndent = ( 2 0 )

set index = 0
foreach application (${applicationIndex})
  @ index++
  if ( $application == da ) then
    set daIndex = $index
  endif
  if ( $application == omm ) then
    set ommIndex = $index
  endif
end

## ABI super-obbing footprint, set independently
#  for da and omm using applicationIndex
#OPTIONS: 15X15, 59X59
set ABISuperOb = (59X59 59X59)

## AHI super-obbing footprint set independently
#  for da and omm using applicationIndex)
#OPTIONS: 15X15, 101X101
set AHISuperOb = (101X101 101X101)

#
# OMM/VARBC settings
# =============================================
## omm
# controls name of omm jobs
# TODO: enable varbc-only jobs including offline coefficient initialization
# OPTIONS: omm, [TODO: varbc]
setenv omm  omm
## abi, ahi
# adds super-obbing resolution for omm
set abi = abi$ABISuperOb[$ommIndex]
set ahi = ahi$AHISuperOb[$ommIndex]
## OMMObsList
# OPTIONS: $defaultObsList, cldamsua, allmhs, clr$abi, all$abi, clr$ahi, all$ahi
set OMMObsList = ($defaultObsList cldamsua allmhs all$abi all$ahi)
#set OMMObsList = (all$abi all$ahi clr$abi clr$ahi)
#set OMMObsList = ($defaultObsList cldamsua allmhs clr$abi all$abi clr$ahi all$ahi)
#set OMMObsList = (clramsua clr$abi)


#
# DA settings
# =============================================
# adds super-obbing resolution for da
set abi = abi$ABISuperOb[$daIndex]
set ahi = ahi$AHISuperOb[$daIndex]
## DAObsList
#OPTIONS: $defaultObsList, cldamsua, clr$abi, all$abi, clr$ahi, all$ahi
# clr == clear-sky
# all == all-sky
# cld == cloudy-sky

set DAObsList = ($defaultObsList)
#set DAObsList = ($defaultObsList clr$abi)
#set DAObsList = ($defaultObsList all$abi)
#set DAObsList = ($defaultObsList clr$ahi)
#set DAObsList = ($defaultObsList all$ahi)
#set DAObsList = ($defaultObsList all$abi all$ahi)

## InDBDir and OutDBDir control the names of the database directories
# on input and output from jedi applications
setenv InDBDir  dbIn
setenv OutDBDir dbOut

## DAType
#OPTIONS: ${omm}, omf, varbc, 3dvarId, 3denvar, eda_3denvar
setenv DAType eda_3denvar

setenv nEnsDAMembers 1
if ( "$DAType" =~ *"eda"* ) then
  #setenv nEnsDAMembers 5
  setenv nEnsDAMembers 20
endif
setenv RTPPInflationFactor 0.0
setenv ABEInflation False
setenv ABEIChannel 8
setenv LeaveOneOutEDA True
setenv LeaveOneOutName LeaveOneOut

## ExpSuffix1: give an experiment a unique suffix to distinguish it from others
set ExpSuffix1 = ''
set ExpSuffix1 = '_newDirectoryVariables'

#GEFS reference case (override above settings)
#====================================================
#setenv DAType eda_3denvar
#setenv nEnsDAMembers 20
#setenv RTPPInflationFactor 0.0
#setenv LeaveOneOutEDA False
#set ExpSuffix1 = _GEFSVerify
#====================================================

## ExpName - experiment name
#(1) populate unique suffix
set ExpSuffix0 = '_NMEM'${nEnsDAMembers}

if ($nEnsDAMembers > 1 && ${RTPPInflationFactor} != "0.0") set ExpSuffix0 = ${ExpSuffix0}_RTPP${RTPPInflationFactor}
if ($nEnsDAMembers > 1 && ${LeaveOneOutEDA} == True) set ExpSuffix0 = ${ExpSuffix0}_${LeaveOneOutName}
if ($nEnsDAMembers > 1 && ${ABEInflation} == True) set ExpSuffix0 = ${ExpSuffix0}_ABEI_BT${ABEIChannel}

#(2) add observation selection info
## make experiment title from DA/OMM settings
setenv ExpObsName ''
if ( "$DAType" == "${omm}" ) then
  set expObsList=($OMMObsList)
else
  set expObsList=($DAObsList)
endif

set MWNoBias = no_bias
set MWGSIBC = bias_corr
set MWBiasCorrect = $MWGSIBC

set GEOIRNoBias = _no-bias-correct
set GEOIRClearBC = _const-bias-correct
set ABIBiasCorrect = $GEOIRNoBias
set AHIBiasCorrect = $GEOIRNoBias


foreach obs ($expObsList)
  set isDefault = False
  foreach default ($defaultObsList)
    if ("$obs" =~ *"$default"*) then
      set isDefault = True
    endif
  end
  if ( $isDefault == False ) then
    setenv ExpObsName ${ExpObsName}_${obs}
  endif
  if ( "$obs" =~ "clrabi"* ) then
    set ABIBiasCorrect = $GEOIRClearBC
  endif
  if ( "$obs" =~ "clrahi"* ) then
    set AHIBiasCorrect = $GEOIRClearBC
  endif
end

#(3) combine for whole ExpName
setenv ExpName ${DAType}${ExpObsName}${ExpSuffix0}${ExpSuffix1}

#
# verification settings
# =============================================
## File Prefixes for obs, geovals, and hofx-diagnostics
# NOTE: these are self-consistent across multiple applications
#       and can be changed to any non-empty string
setenv obsPrefix      obsout
setenv geoPrefix      geoval
setenv diagPrefix     ydiags


#
# cycling settings
# =============================================

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

##################################
## mesh-specific settings
##################################

## 120km mesh
## ----------

## grid-spacing, time step, and thinning
setenv MPASGridDescriptor 120km
setenv MPASnCells 40962
setenv MPASTimeStep 720.0
setenv MPASDiffusionLengthScale 120000.0
# TODO: enable logic (somewhere else) to use different super-obbing/thinning for DA/OMM jobs
setenv RADTHINDISTANCE     "200.0"
setenv RADTHINAMOUNT       "0.98"

## job length and node/pe requirements
setenv CyclingFCJobMinutes 5
setenv CyclingFCNodes 4
setenv CyclingFCPEPerNode 32

setenv ExtendedFCJobMinutes 40
setenv ExtendedFCNodes ${CyclingFCNodes}
setenv ExtendedFCPEPerNode ${CyclingFCPEPerNode}

setenv CalcOMMJobMinutes 10
setenv CalcOMMNodes 1
setenv CalcOMMPEPerNode 36
setenv CalcOMMMemory 109

setenv VerifyObsNodes 1
setenv VerifyObsPEPerNode 36
setenv VerifyModelNodes 1
setenv VerifyModelPEPerNode 36

setenv CyclingDAJobMinutes 25
setenv CyclingDAMemory 45
#setenv CyclingDAMemory 109
if ( "$DAType" =~ *"eda"* || "$DAType" == "${omm}") then
  setenv CyclingDANodesPerMember 2
  setenv CyclingDAPEPerNode      18
else
  setenv CyclingDANodesPerMember 4
  setenv CyclingDAPEPerNode      32
endif

setenv CyclingInflationJobMinutes 25
setenv CyclingInflationMemory 109
setenv CyclingInflationNodesPerMember ${CalcOMMNodes}
setenv CyclingInflationPEPerNode      ${CalcOMMPEPerNode}

## 30km mesh
## ----------

## grid-spacing, time step, and thinning
#setenv MPASGridDescriptor 30km
#setenv MPASnCells 655362
#setenv MPASTimeStep 180.0
#setenv MPASDiffusionLengthScale 15000.0
#setenv RADTHINDISTANCE    "60.0"
#setenv RADTHINAMOUNT      "0.75"

## job length and node/pe requirements
#setenv CyclingFCJobMinutes     10
#setenv CyclingFCNodes 8
#setenv CyclingFCPEPerNode 32

#setenv ExtendedFCJobMinutes     60
#setenv ExtendedFCNodes ${CyclingFCNodes}
#setenv ExtendedFCPEPerNode ${CyclingFCPEPerNode}

#setenv CalcOMMJobMinutes 10
#setenv CalcOMMNodes 32
#setenv CalcOMMPEPerNode 16
#setenv CalcOMMMemory 109

#setenv CyclingDAJobMinutes 25
#setenv CyclingDAMemory 109
#if ( "$DAType" =~ *"eda"* ) then
#  setenv CyclingDANodesPerMember 64
#  setenv CyclingDAPEPerNode      8
#else
#  setenv CyclingDANodesPerMember 64
#  setenv CyclingDAPEPerNode      8
#endif


######################################
## state file descriptors
######################################
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


####################################
## workflow-relevant state variables
####################################
setenv MPASDiagVariables cldfrac
setenv MPASSeaVariables sst,xice
set MPASHydroVariables = (qc qi qg qr qs)

set StandardAnalysisVariables = ( \
  spechum \
  surface_pressure \
  temperature \
  uReconstructMeridional \
  uReconstructZonal \
)
set StandardStateVariables = ( \
  $StandardAnalysisVariables \
  theta \
  rho \
  u \
  index_qv \
  pressure \
  landmask \
  xice \
  snowc \
  skintemp \
  ivgtyp \
  isltyp \
  snowh \
  vegfra \
  u10 \
  v10 \
  lai \
  smois \
  tslb \
  pressure_p \
)
@ CyclingDAPEPerMember = ${CyclingDANodesPerMember} * ${CyclingDAPEPerNode}
setenv CyclingDAPEPerMember ${CyclingDAPEPerMember}

@ CyclingDANodes = ${CyclingDANodesPerMember} * ${nEnsDAMembers}
setenv CyclingDANodes ${CyclingDANodes}

#
# Run directories
# =============================================
## absolute experiment directory
setenv PKGBASE          MPAS-Workflow
setenv EXPUSER          ${USER}
setenv TOP_EXP_DIR      /glade/scratch/${EXPUSER}/pandac
setenv WholeExpName     ${EXPUSER}_${ExpName}_${MPASGridDescriptor}
setenv EXPDIR           ${TOP_EXP_DIR}/${WholeExpName}
setenv TMPDIR /glade/scratch/$USER/temp
mkdir -p $TMPDIR

## immediate subdirectories
setenv CyclingDAWorkDir    ${EXPDIR}/CyclingDA
setenv CyclingFCWorkDir    ${EXPDIR}/CyclingFC
setenv CyclingInflationWorkDir ${EXPDIR}/CyclingInflation
setenv ExtendedFCWorkDir   ${EXPDIR}/ExtendedFC
setenv VerificationWorkDir ${EXPDIR}/Verification

## directories copied from PKGBASE
setenv mainScriptDir  ${EXPDIR}/${PKGBASE}

setenv CONFIGDIR        ${mainScriptDir}/config
setenv daModelConfigDir ${CONFIGDIR}/mpas/da
setenv fcModelConfigDir ${CONFIGDIR}/mpas/fc
setenv rtppModelConfigDir ${CONFIGDIR}/mpas/rtpp

## workflow tools
set pyDir = ${mainScriptDir}/tools
set pyTools = (memberDir advanceCYMDH nSpaces)
foreach tool ($pyTools)
  setenv ${tool} "python ${pyDir}/${tool}.py"
end

## directory string formatter for EDA members
# third argument to memberDir.py
setenv flowMemFmt "/mem{:03d}"

#set prevFirstCycleDate = `$advanceCYMDH ${FirstCycleDate} -${CyclingWindowHR}`
set yy = `echo ${prevFirstCycleDate} | cut -c 1-4`
set mm = `echo ${prevFirstCycleDate} | cut -c 5-6`
set dd = `echo ${prevFirstCycleDate} | cut -c 7-8`
set hh = `echo ${prevFirstCycleDate} | cut -c 9-10`
set prevFirstFileDate = ${yy}-${mm}-${dd}_${hh}.00.00
#set prevFirstNMLDate = ${yy}-${mm}-${dd}_${hh}:00:00
#set prevFirstConfDate = ${yy}-${mm}-${dd}T${hh}:00:00Z

#
# static data directories
# =============================================
setenv STATICUSER       guerrett
setenv TOP_STATIC_DIR   /glade/work/${STATICUSER}/pandac
setenv FIXED_INPUT      ${TOP_STATIC_DIR}/fixed_input
setenv PANDACCommonData /glade/p/mmm/parc/liuz/pandac_common

## deterministic input
#GFS
#setenv GFS6hfcFORFirstCycle  /glade/work/liuz/pandac/fix_input/${MPASGridDescriptor}_1stCycle_background/${prevFirstCycleDate} --> deprecate soon 25-Feb-2021
setenv GFS6hfcFORFirstCycle ${PANDACCommonData}/${MPASGridDescriptor}_1stCycle_background/${prevFirstCycleDate}
setenv GFSAnaDir ${PANDACCommonData}/${MPASGridDescriptor}_GFSANA

## ensemble input
#GEFS
set gefsMemFmt = "/{:02d}"
set nGEFSMembers = 20
set GEFS6hfcFOREnsBDir = ${PANDACCommonData}/${MPASGridDescriptor}_EnsFC
set GEFS6hfcFOREnsBFilePrefix = EnsForCov
set GEFSAnaDir = /glade/p/mmm/parc/guerrett/pandac/fixed_input/${MPASGridDescriptor}
set GEFS6hfcFORFirstCycle = ${GEFSAnaDir}/${MPASGridDescriptor}EnsFCFirstCycle/${prevFirstCycleDate}

## deterministic DA
setenv firstDetermFCDir ${GFS6hfcFORFirstCycle}
setenv fixedEnsBMemFmt "${gefsMemFmt}"
setenv fixedEnsBNMembers ${nGEFSMembers}
setenv fixedEnsBDir ${GEFS6hfcFOREnsBDir}
setenv fixedEnsBFilePrefix ${GEFS6hfcFOREnsBFilePrefix}

## ensemble DA
setenv firstEnsFCMemFmt "${gefsMemFmt}"
setenv firstEnsFCNMembers 80
setenv firstEnsFCDir ${GEFS6hfcFORFirstCycle}

if ( $nEnsDAMembers > $firstEnsFCNMembers ) then
  echo "WARNING: nEnsDAMembers must be <= nFixedMembers, changing ensemble size"
  setenv nEnsDAMembers ${nFixedMembers}
endif
setenv dynamicEnsBMemFmt "${flowMemFmt}"
setenv dynamicEnsBNMembers ${nEnsDAMembers}
setenv dynamicEnsBDir ${CyclingFCWorkDir}
setenv dynamicEnsBFilePrefix ${FCFilePrefix}

## MPASSeaVariables file info
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


#############
## MPAS-Model
#############
## directory containing x1.${MPASnCells}.graph.info* files
setenv GraphInfoDir /glade/work/duda/static_moved_to_campaign

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

############
## MPAS-JEDI
############
## Background Error
# Last updated 08 Feb 2021
# works for 36pe/128pe and 120km domain
#setenv bumpLocDir ${FIXED_INPUT}/${MPASGridDescriptor}/bumploc_${CyclingDAPEPerMember}pe_20210208
setenv bumpLocDir /glade/scratch/bjung/x_bumploc_20210208
setenv bumpLocPrefix bumploc_2000_5

## Observations
setenv CONVObsDir          ${TOP_STATIC_DIR}/obs/conv

set baseMWObsDir = /glade/p/mmm/parc/vahl/gsi_ioda/
set MWObsDir = ()
foreach application (${applicationIndex})
  set MWObsDir = ($MWObsDir \
    ${baseMWObsDir} \
  )
end
set MWObsDir[$daIndex] = $MWObsDir[$daIndex]$MWBiasCorrect
set MWObsDir[$ommIndex] = $MWObsDir[$ommIndex]$MWNoBias

set baseABIObsDir = ${TOP_STATIC_DIR}/obs/ABIASR/IODANC_THIN15KM_SUPEROB
set ABIObsDir = ()
foreach SuperOb ($ABISuperOb)
  set ABIObsDir = ($ABIObsDir \
    ${baseABIObsDir}${SuperOb} \
  )
end
set ABIObsDir[$daIndex] = $ABIObsDir[$daIndex]$ABIBiasCorrect
set ABIObsDir[$ommIndex] = $ABIObsDir[$ommIndex]$GEOIRNoBias

set baseAHIObsDir = ${TOP_STATIC_DIR}/obs/AHIASR/IODANC_SUPEROB
#Note: AHI is linked from /glade/work/wuyl/pandac/work/fix_input/AHI_OBS
set AHIObsDir = ()
foreach SuperOb ($AHISuperOb)
  set AHIObsDir = ($AHIObsDir \
    ${baseAHIObsDir}${SuperOb} \
  )
end
set AHIObsDir[$daIndex] = $AHIObsDir[$daIndex]$AHIBiasCorrect
set AHIObsDir[$ommIndex] = $AHIObsDir[$ommIndex]$GEOIRNoBias

## CRTM
setenv CRTMTABLES            ${FIXED_INPUT}/crtm_bin/

## VARBC
setenv INITIAL_VARBC_TABLE   ${FIXED_INPUT}/satbias/satbias_crtm_in
setenv VARBC_ANA             Data/satbias_crtm_ana


#
# code build/run environment
# =============================================
source /etc/profile.d/modules.csh
setenv OPT /glade/work/miesch/modules
module use $OPT/modulefiles/core

set COMPILER=gnu-openmpi
#set COMPILER=intel-impi
set mainModule = ${COMPILER}

module purge
module load jedi/${mainModule}

setenv CUSTOMPIO         ""
if ( CUSTOMPIO != "" ) then
  module unload pio
endif

module load nco
limit stacksize unlimited
setenv OOPS_TRACE 0
setenv OOPS_DEBUG 0
#setenv OOPS_TRAPFPE 1
setenv GFORTRAN_CONVERT_UNIT 'big_endian:101-200'
setenv F_UFMTENDIAN 'big:101-200'
setenv OMP_NUM_THREADS 1

module load python/3.7.5

#
# build directory structures
# =============================================
setenv BUILDUSER         guerrett
setenv TOP_BUILD_DIR     /glade/work/${BUILDUSER}/pandac


############
## MPAS-JEDI
############
set BundleFeatureName = ''
set BundleFeatureName = '_19FEB2021'

if ( "$DAType" =~ *"eda"* ) then
  setenv DAEXE           mpasjedi_eda.x
else
  setenv DAEXE           mpasjedi_variational.x
endif
setenv DABuild         mpas-bundle${CUSTOMPIO}_${COMPILER}${BundleFeatureName}
setenv DABuildDir      ${TOP_BUILD_DIR}/build/${DABuild}/bin

setenv OMMEXE          mpasjedi_hofx_nomodel.x
setenv OMMBuild        mpas-bundle${CUSTOMPIO}_${COMPILER}${BundleFeatureName}
setenv OMMBuildDir     ${TOP_BUILD_DIR}/build/${OMMBuild}/bin

setenv RTPPEXE         mpasjedi_rtpp.x
setenv RTPPBuild       mpas-bundle${CUSTOMPIO}_${COMPILER}_feature--rtpp_app
setenv RTPPBuildDir    ${TOP_BUILD_DIR}/build/${RTPPBuild}/bin

setenv appyaml         jedi.yaml


#############
## MPAS-Model
#############
setenv MPASCore        atmosphere
setenv FCEXE           mpas_${MPASCore}
set FCProject = MPAS
setenv FCBuild         mpas-bundle${CUSTOMPIO}_${COMPILER}${BundleFeatureName}
setenv FCBuildDir      ${TOP_BUILD_DIR}/build/${FCBuild}/bin
setenv FCLookupDir     ${TOP_BUILD_DIR}/build/${FCBuild}/${FCProject}/core_${MPASCore}
set FCLookupFileGlobs = (.TBL .DBL DATA COMPATABILITY VERSION)


#####################
## Verification tools
#####################
setenv meanStateExe      average_netcdf_files_parallel_mpas_${COMPILER}.x
setenv meanStateBuildDir /glade/work/guerrett/pandac/work/meanState
#TODO: add these to the repo, possibly under graphics/plot/postprocess/tools directory
#setenv pyObsDir          ${FIXED_INPUT}/graphics_obs
setenv pyObsDir          ${FIXED_INPUT}/graphics_obs_abei
setenv pyModelDir        ${FIXED_INPUT}/graphics_model


#
# job submission settings
# =============================================
## *AccountNumber
# OPTIONS: NMMM0015, NMMM0043
setenv StandardAccountNumber NMMM0043
setenv CYAccountNumber ${StandardAccountNumber}
setenv VFAccountNumber ${StandardAccountNumber}

## *QueueName
# OPTIONS: economy, regular, premium
setenv CYQueueName premium
setenv VFQueueName economy

if ($ABEInflation == True) then
  setenv EnsMeanBGQueueName ${CYQueueName}
  setenv EnsMeanBGAccountNumber ${CYAccountNumber}
else
  setenv EnsMeanBGQueueName ${VFQueueName}
  setenv EnsMeanBGAccountNumber ${VFAccountNumber}
endif
