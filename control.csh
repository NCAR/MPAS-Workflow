#!/bin/csh -f


## FirstCycleDate
# used to initiate new experiments
setenv FirstCycleDate 2018041500

set applicationIndex = ( da omm )
set applicationObsIndent = ( 2 0 )

#
# OMM/VARBC settings
# =============================================
## omm
# controls name of omm jobs
# TODO: enable varbc-only jobs including offline coefficient initialization
# OPTIONS: omm, [TODO: varbc]
setenv omm  omm

## OMMObsList
# OPTIONS: conv, clramsua, cldamsua, clrabi, allabi, clrahi, allahi
set OMMObsList = (conv clramsua cldamsua allabi allahi)
#set OMMObsList = (conv clramsua cldamsua clrabi allabi clrahi allahi)
#set OMMObsList = (clramsua clrabi)
#set OMMObsList = (allabi_SCI)
#set OMMObsList = (allabi_constObsError)


#
# DA settings
# =============================================
## DAObsList
#OPTIONS: conv, clramsua, cldamsua, clrabi, allabi, clrahi, allahi
# clr == clear-sky
# all == all-sky
# cld == cloudy-sky
#set DAObsList = ()
set DAObsList = (conv clramsua)
#set DAObsList = (conv clramsua clrabi)
#set DAObsList = (conv clramsua allabi)

## InDBDir and OutDBDir control the names of the database directories
# on input and output from jedi applications
setenv InDBDir  dbIn
setenv OutDBDir dbOut

## DAType
#OPTIONS: ${omm}, omf, varbc, 3dvarId, 3denvar, eda_3denvar
setenv DAType 3denvar

setenv nEnsDAMembers 1
if ( "$DAType" =~ *"eda"* ) then
  #setenv nEnsDAMembers 5
  setenv nEnsDAMembers 20
endif
setenv RTPPInflationFactor 0.75
setenv LeaveOneOutEDA False
set ExpSuffix = ''

#GEFS reference case (override above settings)
#====================================================
#setenv DAType eda_3denvar
#setenv nEnsDAMembers 20
#setenv RTPPInflationFactor 0.0
#setenv LeaveOneOutEDA False
#set ExpSuffix = _GEFSVerify
#====================================================

## ExpName - experiment name
#(1) populate unique suffix
set ExpSuffix = ${ExpSuffix}'_NMEM'${nEnsDAMembers}

if ($nEnsDAMembers > 1 && ${RTPPInflationFactor} != "0.0") set ExpSuffix = ${ExpSuffix}_RTPP${RTPPInflationFactor}
if ($nEnsDAMembers > 1 && ${LeaveOneOutEDA} == True) set ExpSuffix = ${ExpSuffix}_LeaveOut

#(2) add observation selection info
## ABI super-obbing footprint (used for both OMM and DA)
#OPTIONS: 15X15, 59X59 
set ABISUPEROB = 15X15

## make experiment title from DA/OMM settings
setenv ExpObsName ''
if ( "$DAType" == "${omm}" ) then
  set expObsList=($OMMObsList)
else
  set expObsList=($DAObsList)
endif
foreach obs ($expObsList)
  setenv ExpObsName ${ExpObsName}_${obs}
  if ( "$obs" =~ *"abi"* ) then
    setenv ExpObsName ${ExpObsName}${ABISUPEROB}
  endif
end

#(3) combine for whole ExpName
setenv ExpName ${DAType}${ExpObsName}${ExpSuffix}

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
setenv updateSea 1

setenv CyclingWindowHR 6                # forecast interval between CyclingDA analyses
setenv ExtendedFCWindowHR 6             # length of verification forecasts
setenv ExtendedFC_DT_HR 6               # interval between OMF verification times of an individual forecast
setenv ExtendedMeanFCTimes T00,T12      # times of the day to run extended forecast from mean analysis
setenv ExtendedEnsFCTimes T00           # times of the day to run ensemble of extended forecasts
setenv DAVFWindowHR ${ExtendedFC_DT_HR} # window of observations included in verification

## 120km
setenv MPASGridDescriptor 120km
setenv MPASnCells 40962
setenv MPASTimeStep 720.0
setenv MPASDiffusionLengthScale 120000.0
# TODO: enable logic (somewhere else) to use different super-obbing/thinning for DA/OMM jobs
setenv RADTHINDISTANCE     "200.0"
setenv RADTHINAMOUNT       "0.98"

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
if ( "$DAType" =~ *"eda"* || "$DAType" == "${omm}") then
  setenv CyclingDANodesPerMember 2
  setenv CyclingDAPEPerNode      18
else
  setenv CyclingDANodesPerMember 4
  setenv CyclingDAPEPerNode      32
endif

setenv CyclingInflationJobMinutes 25
setenv CyclingInflationMemory 45
setenv CyclingInflationNodesPerMember ${CalcOMMNodes}
setenv CyclingInflationPEPerNode      ${CalcOMMPEPerNode}

## 30km
#setenv MPASGridDescriptor 30km
#setenv MPASnCells 655362
#setenv MPASTimeStep 180.0
#setenv MPASDiffusionLengthScale 15000.0
#setenv RADTHINDISTANCE    "60.0"
#setenv RADTHINAMOUNT      "0.75"

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


setenv RSTFilePrefix   restart
setenv ICFilePrefix    mpasin
setenv FirstCycleFilePrefix ${RSTFilePrefix}
#setenv FirstCycleFilePrefix x1.${MPASnCells}.init

setenv FCFilePrefix    mpasout
setenv fcDir           fc
setenv DIAGFilePrefix  diag

setenv ANFilePrefix    an
setenv anDir           ${ANFilePrefix}
setenv BGFilePrefix    bg
setenv bgDir           ${BGFilePrefix}
#setenv anStatePrefix   analysis

setenv TemplateFilePrefix templateFields
setenv staticFieldsFile /glade/p/mmm/parc/liuz/pandac_common/${MPASGridDescriptor}_GFSANA/x1.${MPASnCells}.init.2018-04-14_18.00.00.nc
#setenv staticFieldsFile /glade/p/mmm/parc/liuz/pandac_common/${MPASGridDescriptor}_GFSANA_O3/x1.${MPASnCells}.init.2018-04-14_18.00.00.nc
setenv localStaticFieldsFile static.nc

setenv OrigFileSuffix  _orig


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

setenv nulljob 0
#
# Run directories
# =============================================
## absolute experiment directory
setenv PKGBASE          MPAS-Workflow
setenv EXPUSER          ${USER}
setenv TOP_EXP_DIR      /glade/scratch/${EXPUSER}/pandac
setenv WholeExpName     ${EXPUSER}_${ExpName}_${MPASGridDescriptor}
setenv EXPDIR           ${TOP_EXP_DIR}/${WholeExpName}

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

## directory string formatter for EDA members
# argument to memberDir.py
# must match oops/src/oops/util/string_utils::swap_name_member
setenv oopsMemFmt "/mem{:03d}"


#
# static data directories
# =============================================
setenv STATICUSER            guerrett
setenv TOP_STATIC_DIR        /glade/work/${STATICUSER}/pandac
setenv FIXED_INPUT           ${TOP_STATIC_DIR}/fixed_input

## deterministic input
#GFS
setenv GFS6hfcFORFirstCycle  /glade/work/liuz/pandac/fix_input/120km_1stCycle_background/2018041418
#setenv GFSANA6hfc_DIR        ${FIXED_INPUT}/${MPASGridDescriptor}/GFSANA6HFC

## ensemble input
#GEFS
set gefsMemFmt = "/{:02d}"
set nGEFSMembers = 20

set GEFS6hfcFOREnsBDir = /glade/p/mmm/parc/liuz/pandac_common/120km_EnsFC
set GEFS6hfcFOREnsBFilePrefix = EnsForCov

set GEFS6hfcFORFirstCycle = /glade/p/mmm/parc/guerrett/pandac/fixed_input/120km/120kmEnsFCFirstCycle/2018041418

#deterministic DA
setenv firstDetermFCDir ${GFS6hfcFORFirstCycle}
setenv fixedEnsBMemFmt "${gefsMemFmt}"
setenv fixedEnsBNMembers ${nGEFSMembers}
setenv fixedEnsBDir ${GEFS6hfcFOREnsBDir}
setenv fixedEnsBFilePrefix ${GEFS6hfcFOREnsBFilePrefix}

#ensemble DA
setenv firstEnsFCMemFmt "${gefsMemFmt}"
setenv firstEnsFCNMembers ${nGEFSMembers}
setenv firstEnsFCDir ${GEFS6hfcFORFirstCycle}

if ( $nEnsDAMembers > $firstEnsFCNMembers ) then
  echo "WARNING: nEnsDAMembers must be <= nFixedMembers, changing ensemble size"
  setenv nEnsDAMembers ${nFixedMembers}
endif
setenv dynamicEnsBMemFmt "${oopsMemFmt}"
setenv dynamicEnsBNMembers ${nEnsDAMembers}
setenv dynamicEnsBDir ${CyclingFCWorkDir}
setenv dynamicEnsBFilePrefix ${FCFilePrefix}

#setenv GFSANA6hfc_OMF_DIR    ${FIXED_INPUT}/${MPASGridDescriptor}/GFSANA6HFC
#setenv GFSANA_DIR            ${FIXED_INPUT}/${MPASGridDescriptor}/GFSANA
setenv GFSSST_DIR            ${FIXED_INPUT}/${MPASGridDescriptor}/GFSSST

## MPAS-Model and MPAS-JEDI
setenv GRAPHINFO_DIR         ${FIXED_INPUT}/${MPASGridDescriptor}/graph

## Background Error
setenv bumpLocDir            ${FIXED_INPUT}/${MPASGridDescriptor}/bumploc_${CyclingDAPEPerMember}pe
setenv bumpLocPrefix         bumploc_2000_5

## Observations
setenv CONV_OBS_DIR          ${TOP_STATIC_DIR}/obs/conv
#setenv CONV_OBS_DIR          ${TOP_STATIC_DIR}/obs/conv_liuz
setenv AMSUA_OBS_DIR         /glade/p/mmm/parc/vahl/gsi_ioda/bias_corr

# TODO: enable logic (somewhere else) to use different super-obbing/thinning for DA/OMM jobs
# setenv ABI_OBS_DIR          ${TOP_STATIC_DIR}/obs/ABIASR/IODANC_THIN15KM_SUPEROB${ABISUPEROB}_no-bias-correct
setenv ABI_OBS_DIR           ${TOP_STATIC_DIR}/obs/ABIASR/IODANC_THIN15KM_SUPEROB${ABISUPEROB}_const-bias-correct

setenv AHI_OBS_DIR           /glade/work/wuyl/pandac/work/fix_input/AHI_OBS/ioda_cnst_bias

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

#USE FOR OLD CODE (BEFORE APRIL 15)
#module load jedi/gnu-openmpi/7.4.0-v0.1

setenv CUSTOMPIO         ""
if ( CUSTOMPIO != "" ) then
  module unload pio
endif

module load nco
limit stacksize unlimited
setenv OOPS_TRACE 0
setenv OOPS_DEBUG 0
#setenv OOPS_TRAPFPE 1
setenv GFORTRAN_CONVERT_UNIT 'native;big_endian:101-200'
setenv F_UFMTENDIAN 'big:101-200'

module load python/3.7.5

#
# build directory structures
# =============================================
setenv BUILDUSER         ${USER}
setenv TOP_BUILD_DIR     /glade/work/${BUILDUSER}/pandac
#MPAS-JEDI
if ( "$DAType" =~ *"eda"* ) then
  setenv DAEXE           mpasjedi_eda.x
else
  setenv DAEXE           mpasjedi_variational.x
endif
setenv DABuild         mpas-bundle${CUSTOMPIO}_${COMPILER}
setenv DABuildDir      ${TOP_BUILD_DIR}/build/${DABuild}/bin

setenv OMMEXE          mpasjedi_hofx_nomodel.x

setenv OMMBuild        mpas-bundle${CUSTOMPIO}_${COMPILER}
setenv OMMBuildDir     ${TOP_BUILD_DIR}/build/${OMMBuild}/bin

setenv RTPPEXE         mpasjedi_rtpp.x
setenv RTPPBuild       mpas-bundle${CUSTOMPIO}_${COMPILER}_feature--rtpp_app
setenv RTPPBuildDir    ${TOP_BUILD_DIR}/build/${RTPPBuild}/bin


#setenv HOFXEXE         mpasjedi_hofx_nomodel.x

setenv appyaml         jedi.yaml

#MPAS-Model
setenv MPASCore        atmosphere
setenv FCEXE           mpas_${MPASCore}
set FCProject = MPAS
setenv FCBuild         mpas-bundle${CUSTOMPIO}_${COMPILER}
setenv FCBuildDir      ${TOP_BUILD_DIR}/build/${FCBuild}/bin
setenv FCLookupDir     ${TOP_BUILD_DIR}/build/${FCBuild}/${FCProject}/core_${MPASCore}
set FCLookupFileGlobs = (.TBL .DBL DATA COMPATABILITY VERSION)

#Verification tools
setenv meanStateExe      average_netcdf_files_parallel_mpas_${COMPILER}.x
setenv meanStateBuildDir /glade/work/guerrett/pandac/work/meanState
#TODO: add these to the repo, possibly under graphics/plot/postprocess/tools directory
setenv pyObsDir          ${FIXED_INPUT}/graphics_obs
setenv pyModelDir        ${FIXED_INPUT}/graphics_model

#Cycling tools
set pyDir = ${mainScriptDir}/tools
set pyTools = (memberDir advanceCYMDH nSpaces)
foreach tool ($pyTools)
  setenv ${tool} "python ${pyDir}/${tool}.py"
end


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
