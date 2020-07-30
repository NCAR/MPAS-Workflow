#!/bin/csh -f


## FirstCycleDate
# used to initiate new experiments
setenv FirstCycleDate 2018041500

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
set OMMObsList = (conv clramsua cldamsua clrabi allabi clrahi allahi)
#set OMMObsList = (clramsua clrabi)
#set OMMObsList = (allabi_SCI)
#set OMMObsList = (allabi_constObsError)


#
# DA settings
# =============================================
## InDBDir and OutDBDir control the names of the database directories
# on input and output from jedi applications
setenv InDBDir  dbIn
setenv OutDBDir dbOut

## DAType
#OPTIONS: ${omm}, omf, varbc, 3dvarId, 3denvar, eda_3denvar
setenv DAType eda_3denvar

setenv nEnsDAMembers 1
if ( "$DAType" =~ *"eda"* ) then
  setenv nEnsDAMembers 20
endif

## DAObsList
#OPTIONS: conv, clramsua, cldamsua, clrabi, allabi, clrahi, allahi
#NOTE: the "clr" and "all" prefixes are used for clear-sky
#      and all-sky scenes for radiances.  The "all" prefix
#      signals to DA and OMM jobs to include hydrometeors among
#      the analysis variables.
#set DAObsList = ()
set DAObsList = (conv clramsua)
#set DAObsList = (conv clramsua clrabi)
#set DAObsList = (conv clramsua allabi)

## ABI super-obbing footprint (used for both OMM and DA)
#OPTIONS: 15X15, 59X59 
set ABISUPEROB = 15X15

## make experiment title from DA/OMM settings
setenv ExpName ${DAType}
if ( "$DAType" == "${omm}" ) then
  set expObsList=($OMMObsList)
else
  set expObsList=($DAObsList)
endif
foreach obs ($expObsList)
  setenv ExpName ${ExpName}_${obs}
  if ( "$obs" =~ *"abi"* ) then
    setenv ExpName ${ExpName}${ABISUPEROB}
  endif
end

## add unique suffix
set ExpSuffix = "_NMEM"${nEnsDAMembers}
setenv ExpName ${ExpName}${ExpSuffix}

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
setenv MPAS_RES            120km
setenv MPAS_NCELLS         40962
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
setenv CalcOMMNodes 2
setenv CalcOMMPEPerNode 18

setenv VerifyObsNodes 1
setenv VerifyObsPEPerNode 18
setenv VerifyModelNodes 1
setenv VerifyModelPEPerNode 18

setenv CyclingDAJobMinutes 25
if ( "$DAType" =~ *"eda"* || "$DAType" == "${omm}") then
  setenv CyclingDANodesPerMember ${CalcOMMNodes}
  setenv CyclingDAPEPerNode      ${CalcOMMPEPerNode}
else
  setenv CyclingDANodesPerMember 4
  setenv CyclingDAPEPerNode      32
endif

## 30km
#setenv MPAS_RES           30km
#setenv MPAS_NCELLS        655362
#setenv RADTHINDISTANCE    "60.0"
#setenv RADTHINAMOUNT      "0.75"

#setenv CyclingFCJobMinutes     10
#setenv CyclingFCNodes 8
#setenv CyclingFCPEPerNode 32

#setenv ExtendedFCJobMinutes     60
#setenv ExtendedFCNodes ${CyclingFCNodes}
#setenv ExtendedFCPEPerNode ${CyclingFCPEPerNode}

#setenv CalcOMMJobMinutes 10
#setenv CalcOMMNodes 8
#setenv CalcOMMPEPerNode 16

#setenv CyclingDAJobMinutes 25
#if ( "$DAType" =~ *"eda"* ) then
#  setenv CyclingDANodesPerMember ${CalcOMMNodes}
#  setenv CyclingDAPEPerNode      ${CalcOMMPEPerNode}
#else
#  setenv CyclingDANodesPerMember 16
#  setenv CyclingDAPEPerNode      32
#endif

setenv RSTFilePrefix   restart
setenv ICFilePrefix    ${RSTFilePrefix}
setenv FirstCycleFilePrefix ${RSTFilePrefix}
#setenv FirstCycleFilePrefix x1.${MPAS_NCELLS}.init

setenv FCFilePrefix    ${RSTFilePrefix}
setenv fcDir           fc
setenv DIAGFilePrefix  diag

setenv ANFilePrefix    an
setenv anDir           ${ANFilePrefix}
setenv BGFilePrefix    ${RSTFilePrefix}
setenv bgDir           bg

setenv anStatePrefix analysis

setenv MPASDiagVars cldfrac
setenv MPASSeaVars sst,xice
set MPASHydroVars = (qc qi qr qs qg)
setenv MPASStandardANVars theta,rho,u,qv,uReconstructZonal,uReconstructMeridional

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
setenv WholeExpName     ${EXPUSER}_${ExpName}_${MPAS_RES}
setenv EXPDIR           ${TOP_EXP_DIR}/${WholeExpName}

## immediate subdirectories
setenv CyclingDAWorkDir    ${EXPDIR}/CyclingDA
setenv CyclingFCWorkDir    ${EXPDIR}/CyclingFC
setenv ExtendedFCWorkDir   ${EXPDIR}/ExtendedFC
setenv VerificationWorkDir ${EXPDIR}/Verification

## directories copied from PKGBASE
setenv mainScriptDir  ${EXPDIR}/${PKGBASE}

setenv CONFIGDIR        ${mainScriptDir}/config #ONLY used by jediPrep

setenv RESSPECIFICDIR   ${mainScriptDir}/${MPAS_RES} #ONLY used by jediPrep

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
#setenv GFSANA6HFC_DIR        ${FIXED_INPUT}/${MPAS_RES}/${MPAS_RES}_GFSANA6HFC

## ensemble input
#GEFS
set gefsMemFmt = "/{:02d}"
set nGEFSMembers = 20

set GEFS6hfcFOREnsBDir = /glade/scratch/wuyl/test2/pandac/test_120km/120km_EnsFC
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

#setenv GFSANA6HFC_OMF_DIR    ${FIXED_INPUT}/${MPAS_RES}/${MPAS_RES}_GFSANA6HFC
#setenv GFSANA_DIR            ${FIXED_INPUT}/${MPAS_RES}/${MPAS_RES}_GFSANA
setenv GFSSST_DIR            ${FIXED_INPUT}/${MPAS_RES}/${MPAS_RES}_GFSSST

## MPAS-Model and MPAS-JEDI
setenv GRAPHINFO_DIR         ${FIXED_INPUT}/${MPAS_RES}/${MPAS_RES}_graph
setenv DA_NML_DIR            ${FIXED_INPUT}/${MPAS_RES}/${MPAS_RES}_DA_NML
setenv FC_NML_DIR            ${FIXED_INPUT}/${MPAS_RES}/${MPAS_RES}_FC_NML

## Background Error
setenv bumpLocDir            ${FIXED_INPUT}/${MPAS_RES}/${MPAS_RES}_bumploc_${CyclingDAPEPerMember}pe
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

module purge
module load jedi/${COMPILER}

#USE FOR OLD CODE (BEFORE APRIL 15)
#module load jedi/gnu-openmpi/7.4.0-v0.1

#setenv CUSTOMPIO         ""
setenv CUSTOMPIO         _pio2_5_0_debug=1
if ( CUSTOMPIO != "" ) then
  module unload pio
endif

module load nco
limit stacksize unlimited
setenv OOPS_TRACE 1
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
  setenv DAEXE           mpas_eda.x
else
  setenv DAEXE           mpas_variational.x
endif
setenv OMMEXE            mpas_variational.x
setenv HOFXEXE           mpas_hofx_nomodel.x

set BUNDLEBUILD = _build=RelWithDebInfo
set BUILDFEATURE = _feature--eda_sci
#set BUILDFEATURE = _feature--eda_sci_OLD #(before ATLAS, OBS-MODEL Trait separation)

setenv JEDIBUILD         mpas-bundle${CUSTOMPIO}_${COMPILER}${BUNDLEBUILD}${BUILDFEATURE}
setenv JEDIBUILDDIR      ${TOP_BUILD_DIR}/build/${JEDIBUILD}

#MPAS-Model
setenv FCEXE             atmosphere_model
setenv MPASBUILD         MPAS_${COMPILER}_debug=0${CUSTOMPIO}
setenv MPASBUILDDIR      ${TOP_BUILD_DIR}/libs/build/${MPASBUILD}

#Verification tools
setenv meanStateExe      average_netcdf_files_parallel_mpas_${COMPILER}.x
setenv meanStateBuildDir /glade/work/guerrett/pandac/work/meanState
#TODO: add these to the repo, possibly under graphics/plot/postprocess/tools directory
setenv pyObsDir          ${FIXED_INPUT}/graphics_obs
setenv pyModelDir        ${FIXED_INPUT}/graphics_model

#Cycling tools
set pyDir = ${mainScriptDir}/tools
set pyTools = (memberDir advanceCYMDH)
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
