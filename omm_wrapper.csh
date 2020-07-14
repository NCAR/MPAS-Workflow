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

    # parent
    setenv self_DependsOn   DependTypeArg

    # self
    setenv self_Date        DateArg
    setenv self_StateDir    StateDirArg
    setenv self_StatePrefix StatePrefixArg
    setenv self_WorkDir     WorkDirArg
    setenv self_VARBCTable  VARBCTableArg

    mkdir -p ${self_WorkDir}
    ln -sf ${MAIN_SCRIPT_DIR}/setup.csh ${self_WorkDir}/

#------- omm step ---------

    set VFSCRIPT=${self_WorkDir}/vf_job_${self_Date}_${ExpName}.csh
    sed -e 's@DateArg@'${self_Date}'@' \
        -e 's@AccountNumArg@'${VFACCOUNTNUM}'@' \
        -e 's@QueueNameArg@'${VFQUEUENAME}'@' \
        -e 's@ExpNameArg@'${ExpName}'@' \
        vf_job.csh > ${VFSCRIPT}
    chmod 744 ${VFSCRIPT}

    set OMMSCRIPT=${self_WorkDir}/${omm}_job_${self_Date}_${ExpName}.csh
    sed -e 's@OMMTypeArg@CYOMMTypeArg@' \
        -e 's@AccountNumArg@'${VFACCOUNTNUM}'@' \
        -e 's@QueueNameArg@'${VFQUEUENAME}'@' \
        -e 's@ExpNameArg@'${ExpName}'@' \
        -e 's@DateArg@'${self_Date}'@' \
        -e 's@bgStateDirArg@'${self_StateDir}'@' \
        -e 's@bgStatePrefixArg@'${self_StatePrefix}'@' \
        ${omm}_job.csh > ${OMMSCRIPT}
    chmod 744 ${OMMSCRIPT}

    set da_wrapper=${self_WorkDir}/da_wrapper_${self_Date}_${ExpName}.csh
    sed -e 's@DateArg@'${self_Date}'@' \
        -e 's@WindowHRArg@DAWindowHRArg@' \
        -e 's@ObsListArg@OMMObsList@' \
        -e 's@VARBCTableArg@'${self_VARBCTable}'@' \
        -e 's@bgStatePrefixArg@'${self_StatePrefix}'@' \
        -e 's@DATypeArg@'${omm}'@' \
        -e 's@DAModeArg@'${omm}'@' \
        -e 's@DAJobScriptArg@'${OMMSCRIPT}'@' \
        -e 's@DependTypeArg@'${self_DependsOn}'@' \
        -e 's@VFJobScriptArg@'${VFSCRIPT}'@' \
        da_wrapper.csh > ${da_wrapper}
    chmod 744 ${da_wrapper}

    cd ${self_WorkDir}

    if ( ${ONLYVERIFY} == 0 ) then
        echo "CYOMMTypeArg and verification at ${self_Date}"
        ${da_wrapper} >& da_wrapper.log
    else
        echo "verification at ${self_Date}"
        qsub ${VFSCRIPT}
   endif
