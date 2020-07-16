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
    set doJob=1
    set doVerify=1

    #parent
    setenv self_DependsOn   DependTypeArg

    #child
    setenv self_WorkDir     WorkDirArg
    setenv self_JobName     JobNameArg
    setenv self_Date        wrapDateArg
    setenv self_inStateDirs   (wrapStateDirsArg)
    setenv self_inStatePrefix wrapStatePrefixArg
    setenv self_DAType      wrapDATypeArg

    mkdir -p ${self_WorkDir}
    cp ${MAIN_SCRIPT_DIR}/setup.csh ${self_WorkDir}/

    set myWrapper = da_wrapper
    set WrapperScript=${self_WorkDir}/${myWrapper}_${self_Date}.csh
    sed -e 's@inDateArg@'${self_Date}'@' \
        -e 's@inStatePrefixArg@'${self_inStatePrefix}'@' \
        -e 's@WindowHRArg@wrapWindowHRArg@' \
        -e 's@ObsListArg@OMMObsList@' \
        -e 's@VARBCTableArg@wrapVARBCTableArg@' \
        -e 's@DATypeArg@'${self_DAType}'@' \
        -e 's@DAModeArg@wrapDAModeArg@' \
#        -e 's@DAJobScriptArg@'${JobScript}'@' \
#        -e 's@VFJobScriptArg@'${VFScript}'@' \
        ${myWrapper}.csh > ${WrapperScript}
    chmod 744 ${WrapperScript}

    set JobScript=${self_WorkDir}/${self_JobName}_${self_Date}.csh
    sed -e 's@inDateArg@'${self_Date}'@' \
        -e 's@inStateDirsArg@'${self_inStateDirs}'@' \
        -e 's@inStatePrefixArg@'${self_inStatePrefix}'@' \
        -e 's@StateTypeArg@wrapStateTypeArg@' \
        -e 's@DATypeArg@'${self_DAType}'@' \
        -e 's@ExpNameArg@'${ExpName}'@' \
        -e 's@AccountNumberArg@wrapAccountNumberArg@' \
        -e 's@QueueNameArg@wrapQueueNameArg@' \
        -e 's@NNODE@wrapNNODEArg@' \
        -e 's@NPE@wrapNPEArg@g' \
        ${self_JobName}.csh > ${JobScript}
    chmod 744 ${JobScript}

    if ( ${#self_inStateDirs} > 1 ) then
      #NOTE: verification not set up for multiple states yet
      set VFScript=None
    else
      set VFOBSScript=${self_WorkDir}/vfobs_job_${self_Date}.csh
      sed -e 's@inDateArg@'${self_Date}'@' \
          -e 's@AccountNumberArg@'${VFAccountNumber}'@' \
          -e 's@QueueNameArg@'${VFQueueName}'@' \
          -e 's@ExpNameArg@'${ExpName}'@' \
          vfobs_job.csh > ${VFOBSScript}
      chmod 744 ${VFOBSScript}

      set VFMODELScript=${self_WorkDir}/vfmodel_job_${self_Date}.csh
      sed -e 's@inDateArg@'${self_Date}'@' \
          -e 's@inStateDirArg@'${self_inStateDirs}'@' \
          -e 's@inStatePrefixArg@'${self_inStatePrefix}'@' \
          -e 's@AccountNumberArg@'${VFAccountNumber}'@' \
          -e 's@QueueNameArg@'${VFQueueName}'@' \
          -e 's@ExpNameArg@'${ExpName}'@' \
          vfmodel_job.csh > ${VFMODELScript}
      chmod 744 ${VFMODELScript}
    endif

    cd ${self_WorkDir}
    ${WrapperScript} >& ${myWrapper}.log
    echo ${JobScript} > JobScripts
    echo ${VFOBSScript} >> JobScripts
    echo ${VFMODELScript} >> JobScripts

    echo ${self_JobName} > JobTypes
    echo vfobs >> JobTypes
    echo vfmodel >> JobTypes

    echo ${self_DependsOn} > JobDependencies
    echo ${self_JobName} >> JobDependencies
    echo ${self_DependsOn} >> JobDependencies

#    if ( $doJob == 1 ) then
#      echo "${self_DAType}(wrapStateTypeArg) at ${self_Date}"
#      set JALL=(`cat ${JOBCONTROL}/last_${self_DependsOn}_job`)
#      set JDEP = ''
#      foreach J ($JALL)
#        if (${J} != "$nulljob" ) then
#          set JDEP = ${JDEP}:${J}
#        endif
#      end
#      set JDA = `qsub -W depend=afterok${JDEP} ${self_JobScript}`
#      echo "${JDA}" > ${JOBCONTROL}/last_${self_DAMode}_job
#    endif
#
#    if ( $doVerify > 0 && ${VFScript} != "None" ) then
#      echo "verification at ${self_Date}"
#      set JALL=(`cat ${JOBCONTROL}/last_${self_DAMode}_job`)
#      set JDEP = ''
#      foreach J ($JALL)
#        if (${J} != "$nulljob" ) then
#          set JDEP = ${JDEP}:${J}
#        endif
#      end
#      qsub -W depend=afterok:$JDEP ${VFScript}
#    endif
