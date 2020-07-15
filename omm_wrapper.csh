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
    set onlyVerify=0

    setenv self_WorkDir     WorkDirArg
    setenv self_JobType     JobTypeArg
    setenv self_Date        wrapDateArg
    setenv self_DAType      wrapDATypeArg

    mkdir -p ${self_WorkDir}
    cp ${MAIN_SCRIPT_DIR}/setup.csh ${self_WorkDir}/

    if ( "$self_DAType" =~ *"eda"* ) then
      set VFScript=None
    else
      set VFScript=${self_WorkDir}/vf_job_${self_Date}_${ExpName}.csh
      sed -e 's@inDateArg@'${self_Date}'@' \
          -e 's@AccountNumberArg@'${VFAccountNumber}'@' \
          -e 's@QueueNameArg@'${VFQueueName}'@' \
          -e 's@ExpNameArg@'${ExpName}'@' \
          vf_job.csh > ${VFScript}
      chmod 744 ${VFScript}
    endif

    set JobScript=${self_WorkDir}/${self_JobType}_${self_Date}_${ExpName}.csh
    sed -e 's@inDateArg@'${self_Date}'@' \
        -e 's@inStateDirArg@wrapStateDirArg@' \
        -e 's@inStatePrefixArg@wrapStatePrefixArg@' \
        -e 's@StateTypeArg@wrapStateTypeArg@' \
        -e 's@DATypeArg@'${self_DAType}'@' \
        -e 's@ExpNameArg@'${ExpName}'@' \
        -e 's@AccountNumberArg@wrapAccountNumberArg@' \
        -e 's@QueueNameArg@wrapQueueNameArg@' \
        -e 's@NNODE@wrapNNODEArg@' \
        -e 's@NPE@wrapNPEArg@g' \
        ${self_JobType}.csh > ${JobScript}
    chmod 744 ${JobScript}

    set myWrapper = da_wrapper
    set WrapperScript=${self_WorkDir}/${myWrapper}_${self_Date}_${ExpName}.csh
    sed -e 's@DependTypeArg@wrapDependTypeArg@' \
        -e 's@inDateArg@'${self_Date}'@' \
        -e 's@inStatePrefixArg@wrapStatePrefixArg@' \
        -e 's@WindowHRArg@wrapWindowHRArg@' \
        -e 's@ObsListArg@OMMObsList@' \
        -e 's@VARBCTableArg@wrapVARBCTableArg@' \
        -e 's@DATypeArg@'${self_DAType}'@' \
        -e 's@DAModeArg@wrapDAModeArg@' \
        -e 's@DAJobScriptArg@'${JobScript}'@' \
        -e 's@VFJobScriptArg@'${VFScript}'@' \
        ${myWrapper}.csh > ${WrapperScript}
    chmod 744 ${WrapperScript}

    cd ${self_WorkDir}

    if ( ${onlyVerify} == 0 ) then
        echo "${self_DAType}(wrapStateTypeArg) and verification at ${self_Date}"
        ${WrapperScript} >& ${myWrapper}.log
    else
        echo "verification at ${self_Date}"
        qsub ${VFScript}
   endif
