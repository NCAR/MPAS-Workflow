#!/bin/csh -f
#--------------------------------------------------------------
# script to cycle MPAS-JEDI
# Authors:
# Junmei Ban, NCAR/MMM
# Zhiquan (Jake) Liu, NCAR/MMM
# JJ Guerrette, NCAR/MMM
#---------------------------------------------------------------
# 0, setup environment:
# ====================
    source ./setup.csh
#
# 1, Initial and final times of the period:
# =========================================
    set ONLYVERIFY=0

    setenv C_DATE           VFSTATEDATE_in
    setenv WINDOW_HR        WINDOWHR_in
    setenv VF_STATE_DIR     VFSTATEDIR_in
    setenv VF_FILE_PREFIX   VFFILEPREFIX_in
    setenv VF_CYCLE_DIR     VFCYCLEDIR_in
    setenv VARBC_TABLE      VARBCTABLE_in
    setenv DIAG_TYPE        DIAGTYPE_in
    setenv DEPEND_TYPE      DEPENDTYPE_in

    set WORKDIR=${VF_CYCLE_DIR}
    mkdir -p ${WORKDIR}
    ln -sf ${MAIN_SCRIPT_DIR}/setup.csh ${WORKDIR}/

#------- omm step ---------

    set VFSCRIPT=${WORKDIR}/vf_job_${C_DATE}_${EXPNAME}.csh
    sed -e 's@CDATE@'${C_DATE}'@' \
        -e 's@ACCOUNTNUM@'${VFACCOUNTNUM}'@' \
        -e 's@QUEUENAME@'${VFQUEUENAME}'@' \
        -e 's@EXPNAME@'${EXPNAME}'@' \
        vf_job.csh > ${VFSCRIPT}
    chmod 744 ${VFSCRIPT}

    set OMMSCRIPT=${WORKDIR}/${omm}_job_${C_DATE}_${EXPNAME}.csh
    sed -e 's@OMMTYPE@'${DIAG_TYPE}'@' \
        -e 's@CDATE@'${C_DATE}'@' \
        -e 's@ACCOUNTNUM@'${VFACCOUNTNUM}'@' \
        -e 's@QUEUENAME@'${VFQUEUENAME}'@' \
        -e 's@EXPNAME@'${EXPNAME}'@' \
        -e 's@BGDIR@'${VF_STATE_DIR}'@' \
        -e 's@BGSTATEPREFIX@'${VF_FILE_PREFIX}'@' \
        ${omm}_job.csh > ${OMMSCRIPT}
    chmod 744 ${OMMSCRIPT}

    set da_wrapper=${WORKDIR}/da_wrapper_${C_DATE}_${EXPNAME}.csh
    sed -e 's@CDATE@'${C_DATE}'@' \
        -e 's@WINDOWHR@'${WINDOW_HR}'@' \
        -e 's@OBSLIST@OMM_OBS_LIST@' \
        -e 's@VARBCTABLE@'${VARBC_TABLE}'@' \
        -e 's@DATYPESUB@'${omm}'@' \
        -e 's@DAMODESUB@'${omm}'@' \
        -e 's@DIAGTYPE@'${omm}'@' \
        -e 's@DAJOBSCRIPT@'${OMMSCRIPT}'@' \
        -e 's@DEPENDTYPE@'${DEPEND_TYPE}'@' \
        -e 's@VFJOBSCRIPT@'${VFSCRIPT}'@' \
        -e 's@YAMLTOPDIR@'${YAMLTOPDIR}'@' \
        -e 's@RESSPECIFICDIR@'${RESSPECIFICDIR}'@' \
        da_wrapper.csh > ${da_wrapper}
    chmod 744 ${da_wrapper}

    set vf_wrapper=${WORKDIR}/vf_wrapper_${C_DATE}_${EXPNAME}.csh
    sed -e 's@VFSCRIPT@'${VFSCRIPT}'@' \
        vf_wrapper.csh > ${vf_wrapper}
    chmod 744 ${vf_wrapper}

    cd ${WORKDIR}

    if ( ${ONLYVERIFY} == 0 ) then
        echo "${DIAG_TYPE} and verification at ${C_DATE}"
        ${da_wrapper} >& da_wrapper.log
    else
        echo "verification at ${C_DATE}"
        ${vf_wrapper} >& vf_wrapper.log
   endif
