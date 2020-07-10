#!/bin/csh -f

#
# Initial and final times of the period:
# =========================================
# First cycle date (used to initiate new experiments)
setenv FIRSTCYCLE 2018041500 # experiment first cycle date (GFS ANALYSIS)

setenv S_DATE     2018041518 # experiment start date
#setenv E_DATE     2018051418 # experiment end date
setenv E_DATE     2018041800 # experiment end date


#
# OMM/VARBC settings
# =============================================
## omm
# controls name of omm jobs
# TODO: enable varbc-only jobs including offline coefficient initialization
# OPTIONS: omm, [TODO: varbc]
setenv omm  omm

## OMM_OBS_LIST
# OPTIONS: conv, clramsua, cldamsua, clrabi, allabi, clrahi, allahi
set OMM_OBS_LIST = (conv clramsua cldamsua clrabi allabi clrahi allahi)
#set OMM_OBS_LIST = (clramsua clrabi)
#set OMM_OBS_LIST = (allabi_SCI)
#set OMM_OBS_LIST = (allabi_constObsError)


#
# DA settings
# =============================================
## InDBDir and OutDBDir control the names of the database directories
# on input and output from jedi applications
setenv InDBDir  dbIn
setenv OutDBDir dbOut

## DATYPE
#OPTIONS: ${omm}, omf, varbc, 3dvar, 3denvar, eda_3denvar
setenv DATYPE eda_3denvar

setenv nEnsDAMembers 1
if ( "$DATYPE" =~ *"eda"* ) then
  setenv nEnsDAMembers 20
endif

## DA_OBS_LIST
#OPTIONS: conv, clramsua, cldamsua, clrabi, allabi, clrahi, allahi
#set DA_OBS_LIST = ()
set DA_OBS_LIST = (conv clramsua)
#set DA_OBS_LIST = (conv clramsua clrabi)
#set DA_OBS_LIST = (conv clramsua allabi)

## ABI super-obbing footprint (used for both OMM and DA)
#OPTIONS: 15X15, 59X59 
set ABISUPEROB = 15X15

## make experiment title from DA/OMM settings
setenv EXPNAME               ${DATYPE}
if ( "$DATYPE" == "${omm}" ) then
  set EXPOBSLIST=($OMM_OBS_LIST)
else
  set EXPOBSLIST=($DA_OBS_LIST)
endif

set MPASHydroANVars = ""
foreach obs ($EXPOBSLIST)
  setenv EXPNAME ${EXPNAME}_${obs}
  if ( "$obs" =~ *"abi"* ) then
    setenv EXPNAME ${EXPNAME}${ABISUPEROB}
  endif
  if ( "$obs" =~ "all"* ) then
    set MPASHydroANVars = ",qc,qi,qr,qs,qg"
  endif
end

## add unique suffix
set SUFFIX = "_NMEM"${nEnsDAMembers}
setenv EXPNAME ${EXPNAME}${SUFFIX}

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
setenv UPDATESEA         1

setenv CY_WINDOW_HR      6               # interval between cycle DA
setenv FCVF_LENGTH_HR    72              # length of verification forecasts
setenv FCVF_DT_HR        6               # interval between OMF verification times of an individual forecast
setenv FCVF_INTERVAL_HR  12              # interval between OMF forecast initial times
setenv VF_WINDOW_HR      ${FCVF_DT_HR}   # window of observations included in verification

# TODO: enable logic (somewhere else) to use different super-obbing/thinning for DA/OMM jobs
setenv MPAS_RES            120km
setenv MPAS_NCELLS         40962
setenv RADTHINDISTANCE     "200.0"
setenv RADTHINAMOUNT       "0.98"
setenv FCCYJobMinutes      5
setenv FCVFJobMinutes      40
if ( "$DATYPE" =~ *"eda"* ) then
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
#if ( "$DATYPE" =~ *"eda"* ) then
#  setenv DACYNodesPerMember 8
#  setenv DACYPEPerNode      16
#else
#  setenv DACYNodesPerMember 16
#  setenv DACYPEPerNode      32
#endif

setenv RST_FILE_PREFIX   restart
setenv IC_FILE_PREFIX    ${RST_FILE_PREFIX}
setenv FC_FILE_PREFIX    ${RST_FILE_PREFIX}
setenv fcDir             fc
setenv DIAG_FILE_PREFIX  diag

setenv AN_FILE_PREFIX    an
setenv anDir             ${AN_FILE_PREFIX}
setenv BG_FILE_PREFIX    ${RST_FILE_PREFIX}
setenv bgDir             bg

setenv MPASDiagVars      cldfrac
setenv MPASSeaVars       sst,xice
setenv MPASANVars        theta,rho,u,qv,uReconstructZonal,uReconstructMeridional${MPASHydroANVars}

@ DACYPEPerMember = ${DACYNodesPerMember} * ${DACYPEPerNode}
setenv DACYPEPerMember ${DACYPEPerMember}

@ DACYNodes = ${DACYNodesPerMember} * ${nEnsDAMembers}
setenv DACYNodes ${DACYNodes}

#
# Run directories
# =============================================
setenv PKGBASE          MPAS-Workflow
setenv EXPUSER          ${USER}
setenv TOP_EXP_DIR      /glade/scratch/${EXPUSER}/pandac

setenv EXPDIR           ${TOP_EXP_DIR}/${EXPUSER}_${EXPNAME}_${MPAS_RES}
setenv JOBCONTROL       ${EXPDIR}/JOBCONTROL
mkdir -p ${JOBCONTROL}

## Only valid from top-level script directory
setenv MAIN_SCRIPT_DIR  ${EXPDIR}/${PKGBASE}
setenv YAMLTOPDIR       ${MAIN_SCRIPT_DIR}/yamls
setenv RESSPECIFICDIR   ${MAIN_SCRIPT_DIR}/${MPAS_RES}

setenv DA_WORK_DIR      ${EXPDIR}/DACY
setenv FCCY_WORK_DIR    ${EXPDIR}/FCCY
setenv FCVF_WORK_DIR    ${EXPDIR}/FCVF
setenv VF_WORK_DIR      ${EXPDIR}/VF

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
if ( "$DATYPE" =~ *"eda"* ) then
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
#TODO(JJG): move time advancing to python using datetime objects
setenv advanceCYMDH     /glade/u/home/guerrett/bin/advance_cymdh

set pyDir = ${MAIN_SCRIPT_DIR}/tools
set pyTools = (memberDir)
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
