#!/bin/csh -f

#
# Initial and final times of the period:
# =========================================
# First cycle date (used to initiate new experiments)
setenv FIRSTCYCLE 2018041500 # experiment first cycle date

# Experiment start and end date
# NOTE: can be set beyond FIRSTCYCLE in order to continue
# from previously generated workflow output
setenv ExpStartDate 2018041500 
#setenv ExpEndDate 2018051418
setenv ExpEndDate 2018041500


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
#OPTIONS: ${omm}, omf, varbc, 3dvar, 3denvar, eda_3denvar
setenv DAType 3denvar

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
set ExpSuffix = "_NMEM"${nEnsDAMembers}debug
setenv ExpName ${ExpName}${ExpSuffix}

#
# verification settings
# =============================================
## VERIFYAFTERDA
# whether to calculate obs-space verification statistics after DA
# If > 0, a vf_job will be submitted after both omm_job and da_job in da_wrapper
# TODO: add model-space verification
setenv VERIFYAFTERDA  1

## File Prefixes for obs, geovals, and hofx-diagnostics
# NOTE: these are self-consistent across multiple applications
#       and can be changed to any non-empty string
setenv obsPrefix      obsout
setenv geoPrefix      geoval
setenv diagPrefix     ydiags


#
# cycling settings
# =============================================
setenv updateSea         1

setenv CYWindowHR        6               # interval between cycle DA
setenv FCVFWindowHR      72              # length of verification forecasts
setenv FCVF_DT_HR        6               # interval between OMF verification times of an individual forecast
setenv FCVF_INTERVAL_HR  12              # interval between OMF forecast initial times
setenv DAVFWindowHR      ${FCVF_DT_HR}   # window of observations included in verification

# TODO: enable logic (somewhere else) to use different super-obbing/thinning for DA/OMM jobs
setenv MPAS_RES            120km
setenv MPAS_NCELLS         40962
setenv RADTHINDISTANCE     "200.0"
setenv RADTHINAMOUNT       "0.98"
setenv FCCYJobMinutes      5
setenv FCVFJobMinutes      40
if ( "$DAType" =~ *"eda"* || "$DAType" == "${omm}") then
  setenv DACYNodesPerMember 2
  setenv DACYPEPerNode      18
else
  setenv DACYNodesPerMember 4
  setenv DACYPEPerNode      32
endif

#setenv MPAS_RES           30km
#setenv MPAS_NCELLS        655362
#setenv RADTHINDISTANCE    "60.0"
#setenv RADTHINAMOUNT      "0.75"
#setenv FCCYJobMinutes     10
#setenv FCVFJobMinutes     60
#if ( "$DAType" =~ *"eda"* ) then
#  setenv DACYNodesPerMember 8
#  setenv DACYPEPerNode      16
#else
#  setenv DACYNodesPerMember 16
#  setenv DACYPEPerNode      32
#endif

setenv RSTFilePrefix  restart
setenv ICFilePrefix   ${RSTFilePrefix}
setenv FCFilePrefix   ${RSTFilePrefix}
setenv fcDir          fc
setenv DIAGFilePrefix diag

setenv ANFilePrefix   an
setenv anDir          ${ANFilePrefix}
setenv BGFilePrefix   ${RSTFilePrefix}
setenv bgDir          bg

setenv anStatePrefix analysis

setenv MPASDiagVars cldfrac
setenv MPASSeaVars sst,xice
set MPASHydroVars = (qc qi qr qs qg)
setenv MPASStandardANVars theta,rho,u,qv,uReconstructZonal,uReconstructMeridional

@ DACYPEPerMember = ${DACYNodesPerMember} * ${DACYPEPerNode}
setenv DACYPEPerMember ${DACYPEPerMember}

@ DACYNodes = ${DACYNodesPerMember} * ${nEnsDAMembers}
setenv DACYNodes ${DACYNodes}

setenv nulljob 0
#
# Run directories
# =============================================
## absolute experiment directory
setenv PKGBASE          MPAS-Workflow
setenv EXPUSER          ${USER}
setenv TOP_EXP_DIR      /glade/scratch/${EXPUSER}/pandac
setenv EXPDIR           ${TOP_EXP_DIR}/${EXPUSER}_${ExpName}_${MPAS_RES}

## immediate subdirectories
setenv DA_WORK_DIR      ${EXPDIR}/DACY
setenv FCCY_WORK_DIR    ${EXPDIR}/FCCY
setenv FCVF_WORK_DIR    ${EXPDIR}/FCVF
setenv VF_WORK_DIR      ${EXPDIR}/VF
setenv JOBCONTROL       ${EXPDIR}/JOBCONTROL
mkdir -p ${JOBCONTROL}

## directories copied from PKGBASE
setenv MAIN_SCRIPT_DIR  ${EXPDIR}/${PKGBASE}

setenv CONFIGDIR        ${MAIN_SCRIPT_DIR}/config #ONLY used by da_wrapper

setenv RESSPECIFICDIR   ${MAIN_SCRIPT_DIR}/${MPAS_RES} #ONLY used by da_wrapper

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
setenv GFSANA6HFC_FIRSTCYCLE /glade/work/liuz/pandac/fix_input/120km_1stCycle_background/2018041418
setenv GFSANA6HFC_DIR        ${FIXED_INPUT}/${MPAS_RES}/${MPAS_RES}_GFSANA6HFC
#generic names
setenv deterministicICFirstCycle ${GFSANA6HFC_FIRSTCYCLE}

## ensemble input
#GEFS
set GEFSANA6HFC_DIR = /glade/scratch/wuyl/test2/pandac/test_120km/EnsFC
set GEFSANA6HFC_FIRSTCYCLE = ${GEFSANA6HFC_DIR}/2018041418
set gefsMemFmt = "/{:02d}"
set nGEFSMembers = 20

#generic names
setenv fixedEnsembleB ${GEFSANA6HFC_DIR}
setenv ensembleICFirstCycle ${GEFSANA6HFC_FIRSTCYCLE}
setenv fixedEnsMemFmt "${gefsMemFmt}"
setenv nFixedMembers ${nGEFSMembers}

if ( $nEnsDAMembers > $nFixedMembers ) then
  echo "WARNING: nEnsDAMembers must be <= nFixedMembers, changing ensemble size"
  setenv nEnsDAMembers = ${nFixedMembers}
endif


setenv GFSANA6HFC_OMF_DIR    ${FIXED_INPUT}/${MPAS_RES}/${MPAS_RES}_GFSANA6HFC
setenv GFSANA_DIR            ${FIXED_INPUT}/${MPAS_RES}/${MPAS_RES}_GFSANA
setenv GFSSST_DIR            ${FIXED_INPUT}/${MPAS_RES}/${MPAS_RES}_GFSSST

## MPAS-Model and MPAS-JEDI
setenv GRAPHINFO_DIR         ${FIXED_INPUT}/${MPAS_RES}/${MPAS_RES}_graph
setenv DA_NML_DIR            ${FIXED_INPUT}/${MPAS_RES}/${MPAS_RES}_DA_NML
setenv FC_NML_DIR            ${FIXED_INPUT}/${MPAS_RES}/${MPAS_RES}_FC_NML

## Background Error
setenv bumpLocDir            ${FIXED_INPUT}/${MPAS_RES}/${MPAS_RES}_bumploc_${DACYPEPerMember}pe
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
setenv pyObsDir          ${FIXED_INPUT}/graphics_obs
setenv pyModelDir        ${FIXED_INPUT}/graphics_model

#Cycling tools
set pyDir = ${MAIN_SCRIPT_DIR}/tools
set pyTools = (memberDir advanceCYMDH)
foreach tool ($pyTools)
  setenv ${tool} "python ${pyDir}/${tool}.py"
end


#
# job submission settings
# =============================================
#setenv ACCOUNTNUM NMMM0015
setenv ACCOUNTNUM NMMM0043

setenv CYACCOUNTNUM ${ACCOUNTNUM}
setenv VFACCOUNTNUM ${ACCOUNTNUM}

#setenv CYQUEUENAME premium
setenv CYQUEUENAME regular
#setenv CYQUEUENAME economy

#setenv VFQUEUENAME premium
#setenv VFQUEUENAME regular
setenv VFQUEUENAME economy
