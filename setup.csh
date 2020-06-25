#!/bin/csh -f

#
# OMM/VARBC settings
# =============================================
## omm
# controls name of omm jobs
# TODO: enable varbc-only jobs including offline coefficient initialization
# OPTIONS: omm, varbc
setenv omm  omm

## OMM_OBS_LIST
# OPTIONS: conv, clramsua, cldamsua, clrabi, cldabi, clrahi, cldahi
set OMM_OBS_LIST = (conv clramsua cldamsua clrabi cldabi clrahi cldahi)
#set OMM_OBS_LIST = (clramsua clrabi)
#set OMM_OBS_LIST = (cldabi_SCI)
#set OMM_OBS_LIST = (cldabi_constObsError)


#
# DA settings
# =============================================
## DATYPE
#OPTIONS: ${omm}, omf, varbc, 3dvar, 3denvar
setenv DATYPE  3denvar

## DA_OBS_LIST
#OPTIONS: conv, clramsua, cldamsua, clrabi, cldabi, clrahi, cldahi
#set DA_OBS_LIST = ()
#set DA_OBS_LIST = (conv clramsua)
#set DA_OBS_LIST = (conv clramsua clrabi)
set DA_OBS_LIST = (conv clramsua cldabi)

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
foreach obs ($EXPOBSLIST)
  setenv EXPNAME ${EXPNAME}_${obs}
  if ( "$obs" =~ *"abi"* ) then
    setenv EXPNAME ${EXPNAME}${ABISUPEROB}
  endif
end


#
# verification settings
# =============================================
## VERIFYAFTERDA
# whether to calculate obs-space verification statistics after DA
# If > 0, a vf_job will be submitted after both omm_job and da_job in da_wrapper
# TODO: add model-space verification
setenv VERIFYAFTERDA  1


#
# cycling settings
# =============================================
setenv UPDATESST         1

setenv CY_WINDOW_HR      6               # interval between cycle DA
setenv FCVF_LENGTH_HR    72              # length of verification forecasts
setenv FCVF_DT_HR        6               # interval between OMF verification times of an individual forecast
setenv FCVF_INTERVAL_HR  12              # interval between OMF forecast initial times
setenv VF_WINDOW_HR      ${FCVF_DT_HR}   # window of observations included in verification

# TODO: enable logic (somewhere else) to use different super-obbing/thinning for DA/OMM jobs
setenv MPAS_RES          120km
setenv MPAS_NCELLS       40962
setenv RADTHINDISTANCE   "200.0"
setenv RADTHINAMOUNT     "0.98"
setenv FCCYJOBMINUTES    5
setenv FCVFJOBMINUTES    40

#setenv MPAS_RES          30km
#setenv MPAS_NCELLS       655362
#setenv RADTHINDISTANCE   "60.0"
#setenv RADTHINAMOUNT     "0.75"
#setenv FCCYJOBMINUTES    10
#setenv FCVFJOBMINUTES    60

setenv AN_FILE_PREFIX       an
setenv BG_FILE_PREFIX       bg
setenv RST_FILE_PREFIX      restart


#
# Run directories
# =============================================
setenv ORIG_SCRIPT_DIR  `pwd`
setenv currdir          `basename "$ORIG_SCRIPT_DIR"`

setenv TOP_EXPERIMENT_DIR  /glade/scratch/${USER}/pandac

setenv EXPDIR           ${TOP_EXPERIMENT_DIR}/${MPAS_RES}_${EXPNAME}
setenv JOBCONTROL       ${EXPDIR}/JOBCONTROL
mkdir -p ${JOBCONTROL}

## Only valid from top-level script directory
setenv MAIN_SCRIPT_DIR  ${EXPDIR}/${currdir}
setenv YAMLTOPDIR       ${MAIN_SCRIPT_DIR}/yamls
setenv RESSPECIFICDIR   ${MAIN_SCRIPT_DIR}/${MPAS_RES}

setenv DA_WORK_DIR      ${EXPDIR}/DACY
setenv FCCY_WORK_DIR    ${EXPDIR}/FCCY
setenv VF_WORK_DIR      ${EXPDIR}/VF

setenv FCVF_WORK_DIR    ${EXPDIR}/FCVF
setenv OMF_WORK_DIR     ${VF_WORK_DIR}/fc


#
# static data directories
# =============================================
setenv TOP_STATIC_DIR       /glade/work/${USER}/pandac
setenv FIXED_INPUT          ${TOP_STATIC_DIR}/fixed_input
setenv GFSANA6HFC_DIR       ${FIXED_INPUT}/${MPAS_RES}/${MPAS_RES}_GFSANA6HFC
setenv GFSANA6HFC_OMF_DIR   ${FIXED_INPUT}/${MPAS_RES}/${MPAS_RES}_GFSANA6HFC
setenv GFSSST_DIR           ${FIXED_INPUT}/${MPAS_RES}/${MPAS_RES}_GFSSST
setenv GRAPHINFO_DIR        ${FIXED_INPUT}/${MPAS_RES}/${MPAS_RES}_graph
setenv DA_NML_DIR           ${FIXED_INPUT}/${MPAS_RES}/${MPAS_RES}_DA_NML
setenv FC_NML_DIR           ${FIXED_INPUT}/${MPAS_RES}/${MPAS_RES}_FC_NML

setenv BUMP_FILES_DIR       ${FIXED_INPUT}/${MPAS_RES}/${MPAS_RES}_filesbump

setenv CONV_OBS_DIR         ${TOP_STATIC_DIR}/obs/conv
#setenv CONV_OBS_DIR         ${TOP_STATIC_DIR}/obs/conv_liuz
setenv AMSUA_OBS_DIR        /glade/p/mmm/parc/vahl/gsi_ioda/bias_corr

# TODO: enable logic (somewhere else) to use different super-obbing/thinning for DA/OMM jobs
# setenv ABI_OBS_DIR        ${TOP_STATIC_DIR}/obs/ABIASR/IODANC_THIN15KM_SUPEROB${ABISUPEROB}_no-bias-correct
setenv ABI_OBS_DIR        ${TOP_STATIC_DIR}/obs/ABIASR/IODANC_THIN15KM_SUPEROB${ABISUPEROB}_const-bias-correct

setenv AHI_OBS_DIR          /glade/work/wuyl/pandac/work/fix_input/AHI_OBS/ioda_cnst_bias

setenv CRTMTABLES           ${FIXED_INPUT}/crtm_bin/

setenv INITIAL_VARBC_TABLE  ${FIXED_INPUT}/satbias/satbias_crtm_in
setenv VARBC_ANA            Data/satbias_crtm_ana


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

#UNLOAD PIO WHEN USING CUSTOM BUILD
module unload pio

module load nco
limit stacksize unlimited
setenv OOPS_TRACE 1
setenv OOPS_DEBUG 0
#setenv OOPS_TRAPFPE 1
setenv GFORTRAN_CONVERT_UNIT 'native;big_endian:101-200'
setenv F_UFMTENDIAN 'big:101-200'


#
# build directory structures
# =============================================
setenv TOP_BUILD_DIR     /glade/work/${USER}/pandac
#MPAS-JEDI
setenv DAEXE             mpas_variational.x
setenv HOFXEXE           mpas_hofx_nomodel.x
#setenv JEDIBUILD         mpas-bundle_${COMPILER}_build=Debug
#setenv JEDIBUILD         mpas-bundle_${COMPILER}_build=Release
#setenv JEDIBUILD         mpas-bundle_${COMPILER}_build=RelWithDebInfo_feature--symmetric_cloud_impact
#setenv JEDIBUILD         mpas-bundle_${COMPILER}_build=Release_feature--symmetric_cloud_impact
#setenv JEDIBUILD         mpas-bundle_${COMPILER}_build=RelWithDebInfo_features--eda_sci
setenv JEDIBUILD         mpas-bundle_pio2_5_0_debug=1_${COMPILER}_build=RelWithDebInfo_feature--eda_sci
setenv JEDIBUILDDIR      ${TOP_BUILD_DIR}/build/${JEDIBUILD}

#MPAS-Model
setenv FCEXE             atmosphere_model
setenv MPASBUILD         MPAS_${COMPILER}_debug=0
setenv MPASBUILDDIR      ${TOP_BUILD_DIR}/libs/build/${MPASBUILD}

#Verification tools
setenv pyScriptDir       ${FIXED_INPUT}/graphics_git

#Cycling tools
setenv BIN_DIR           $HOME/bin


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
