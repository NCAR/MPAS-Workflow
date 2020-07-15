#!/bin/csh -f
#--------------------------------------------------------------
# script to cycle MPAS-JEDI
# Authors:
# JJ Guerrette, NCAR/MMM
# Zhiquan (Jake) Liu, NCAR/MMM
# Junmei Ban, NCAR/MMM
#---------------------------------------------------------------
# 0, setup environment:
# ====================

    source ./setup.csh
    rm -rf ${MAIN_SCRIPT_DIR}
    mkdir -p ${MAIN_SCRIPT_DIR}
    cp -rpP ./* ${MAIN_SCRIPT_DIR}/
    cd ${MAIN_SCRIPT_DIR}
    echo "$nulljob" > ${JOBCONTROL}/last_ensfc_job
    set member = 1
    while ( $member <= ${nEnsDAMembers} )
      echo "$nulljob" > ${JOBCONTROL}/last_fc_mem${member}_job
      echo "$nulljob" > ${JOBCONTROL}/last_fcvf_mem${member}_job
      @ member++
    end
    echo "$nulljob" > ${JOBCONTROL}/last_da_job
    echo "$nulljob" > ${JOBCONTROL}/last_omm_job
    echo "$nulljob" > ${JOBCONTROL}/last_null_job

    ## workflow component selection
    set doCyclingDA = 1
    set doVerifyANState = 0

    set doCyclingFC = 1
    set doVerifyBGState = 0

    set doExtendedFC = 0
    set doVerifyFCState = 0

    # TODO(JJG): add forceIFExists or skipIFExists
    #            flags for individual
    #            DA/FC/OMM/VF stages

#
# 2, CYCLE:
# =========

    echo "==============================================================\n"
    echo "Cycling workflow for experiment: ${ExpName}\n"
    echo "==============================================================\n"
    ## determine first ExtendedFC date on or after ExpStartDate
    set nextExtendedFCDate = ${FirstCycleDate}
    while ( ${nextExtendedFCDate} < ${ExpStartDate} )
      set nextExtendedFCDate = `$advanceCYMDH ${nextExtendedFCDate} ${ExtendedFC_INTERVAL_HR}`
    end

    set CyclingDAInPrefix = ${BGFilePrefix}
    set CyclingDAOutPrefix = ${ANFilePrefix}

    ## cycling
    setenv cycle_Date ${ExpStartDate}  # initialize cycling date
    while ( ${cycle_Date} <= ${ExpEndDate} )
      set prevDate = `$advanceCYMDH ${cycle_Date} -${CYWindowHR}`
      set nextDate = `$advanceCYMDH ${cycle_Date} ${CYWindowHR}`
      setenv prevDate ${prevDate}
      setenv nextDate ${nextDate}

      ## First cycle "forecast" established offline
      # TODO: make FirstCycleDate behavior part of CyclingFC or seperate application
      #       instead of top-level workflow using zero-length fc_job
      if ( ${cycle_Date} == ${FirstCycleDate} ) then
        mkdir -p ${CyclingFCWorkDir}
        rm -r ${CyclingFCWorkDir}/${prevDate}
        set CyclingFCOutDirs = ()
        set member = 1
        while ( $member <= ${nEnsDAMembers} )
          if ( "$DAType" =~ *"eda"* ) then
            mkdir ${CyclingFCWorkDir}/${prevDate}
            set InitialFC = "$ensembleICFirstCycle"`${memberDir} ens $member "${fixedEnsMemFmt}"`
          else
            set InitialFC = $deterministicICFirstCycle
          endif
          set memDir = `${memberDir} $DAType $member`
          ln -sf ${InitialFC} ${CyclingFCWorkDir}/${prevDate}${memDir}

          set CyclingFCOutDirs = ($CyclingFCOutDirs $InitialFC)
          @ member++
        end
        setenv VARBC_TABLE ${INITIAL_VARBC_TABLE}
        setenv bgStatePrefix ${RSTFilePrefix}
      else
        setenv VARBC_TABLE ${CyclingDAWorkDir}/${prevDate}/${VARBC_ANA}
        setenv bgStatePrefix ${FCFilePrefix}
      endif

      echo "\nWorking on cycle: ${cycle_Date}"

#------- cycling DA ---------
      set WorkDir = ${CyclingDAWorkDir}/${cycle_Date}
      set CyclingDAInDirs = ()
      set CyclingDAOutDirs = ()
      set member = 1
      while ( $member <= ${nEnsDAMembers} )
        set memDir = `${memberDir} $DAType $member`
        set CyclingDAInDirs[$member] = ${WorkDir}/${bgDir}${memDir}
        set CyclingDAOutDirs[$member] = ${WorkDir}/${anDir}${memDir}
        @ member++
      end
      set child_DependsOn=ensfc
      if ( ${doCyclingDA} > 1 ) then
        mkdir -p ${WorkDir}
        cp setup.csh ${WorkDir}/

        echo "\nanalysis at ${cycle_Date}"

        # TODO(JJG): encapsulate the following in a new script that replaces omm_wrapper
        if ( "$DAType" =~ *"eda"* ) then
          set VFScript=None
          # TODO(JJG): cycling-da verification not yet enabled for EDA
        else
          set VFScript=${WorkDir}/vf_job_${cycle_Date}_${ExpName}.csh
          sed -e 's@inDateArg@'${cycle_Date}'@' \
              -e 's@AccountNumberArg@'${VFAccountNumber}'@' \
              -e 's@QueueNameArg@'${VFQueueName}'@' \
              -e 's@ExpNameArg@'${ExpName}'@' \
              vf_job.csh > ${VFScript}
          chmod 744 ${VFScript}
        endif

        set JobScript=${WorkDir}/da_job_${cycle_Date}_${ExpName}.csh
        sed -e 's@inDateArg@'${cycle_Date}'@' \
            -e 's@inStateDirsArg@'$CyclingFCOutDirs'@' \
            -e 's@inStatePrefixArg@'${bgStatePrefix}'@' \
            -e 's@DATypeArg@'${DAType}'@' \
            -e 's@AccountNumberArg@'${CYAccountNumber}'@' \
            -e 's@QueueNameArg@'${CYQueueName}'@' \
            -e 's@ExpNameArg@'${ExpName}'@' \
            -e 's@NNODE@'${CyclingDANodes}'@' \
            -e 's@NPE@'${CyclingDAPEPerNode}'@g' \

            da_job.csh > ${JobScript}
        chmod 744 ${JobScript}

        set myWrapper = da_wrapper
        set WrapperScript=${WorkDir}/${myWrapper}_${cycle_Date}_${ExpName}.csh
        sed -e 's@DependTypeArg@'${child_DependsOn}'@' \
            -e 's@inDateArg@'${cycle_Date}'@' \
            -e 's@inStatePrefixArg@'${bgStatePrefix}'@' \
            -e 's@WindowHRArg@'${CYWindowHR}'@' \
            -e 's@ObsListArg@DAObsList@' \
            -e 's@VARBCTableArg@'${VARBC_TABLE}'@' \
            -e 's@DATypeArg@'${DAType}'@' \
            -e 's@DAModeArg@da@' \
            -e 's@DAJobScriptArg@'${JobScript}'@' \
            -e 's@VFJobScriptArg@'${VFScript}'@' \
            ${myWrapper}.csh > ${WrapperScript}
        chmod 744 ${WrapperScript}

        cd ${WorkDir}

        ${WrapperScript} >& ${myWrapper}.log

#TODO: make this substitution for above three scripts
#        set myWrapper = ${omm}_wrapper
#        set WrapperScript=${myWrapper}_CyclingDA.csh
#        sed -e 's@WorkDirArg@'${WorkDir}'@' \
#            -e 's@JobTypeArg@da_job@' \
#            -e 's@wrapDependTypeArg@'${child_DependsOn}'@' \
#            -e 's@wrapDateArg@'${cycle_Date}'@' \
#            -e 's@wrapStateDirArg@('$CyclingFCOutDirs')@' \
#            -e 's@wrapStatePrefixArg@'${bgStatePrefix}'@' \
#            -e 's@wrapVARBCTableArg@'${VARBC_TABLE}'@' \
#            -e 's@wrapWindowHRArg@'${CYWindowHR}'@' \
#            -e 's@wrapStateTypeArg@@' \
#            -e 's@wrapDATypeArg@'${DAType}'@g' \
#            -e 's@wrapDAModeArg@da@g' \
#            -e 's@wrapAccountNumberArg@'${CYAccountNumber}'@' \
#            -e 's@wrapQueueNameArg@'${CYQueueName}'@' \
#            -e 's@wrapNNODEArg@'${CyclingDANodes}'@' \
#            -e 's@wrapNPEArg@'${CyclingDAPEPerNode}'@g' \
#            ${myWrapper}.csh > ${WrapperScript}
#          chmod 744 ${WrapperScript}
#          ./${WrapperScript}

      endif

#------- verify analysis state ---------
      set myWrapper = ${omm}_wrapper
      set child_DependsOn=da
      set VerifyANDirs = ()

      set member = 1
      while ( $member <= ${nEnsDAMembers} )
        cd ${MAIN_SCRIPT_DIR}
        set VFARGS = ($CyclingDAOutDirs[$member] ${CyclingDAOutPrefix} ${anDir} ${cycle_Date})
        set StateDir = $VFARGS[1]
        set memDir = `${memberDir} $DAType $member`
        set WorkDir = ${VerificationWorkDir}/$VFARGS[3]${memDir}/$VFARGS[4]
        set VerifyANDirs[$member] = $WorkDir

        if ( ${doVerifyANState} > 0 ) then
          set WrapperScript=${myWrapper}_OMA.csh
          sed -e 's@WorkDirArg@'${WorkDir}'@' \
              -e 's@JobTypeArg@'${omm}'_job@' \
              -e 's@wrapDependTypeArg@'${child_DependsOn}'@' \
              -e 's@wrapDateArg@'$VFARGS[4]'@' \
              -e 's@wrapStateDirArg@'${StateDir}'@' \
              -e 's@wrapStatePrefixArg@'$VFARGS[2]'@' \
              -e 's@wrapVARBCTableArg@'${VARBC_TABLE}'@' \
              -e 's@wrapWindowHRArg@'${CYWindowHR}'@' \
              -e 's@wrapStateTypeArg@'$VFARGS[3]'@' \
              -e 's@wrapDATypeArg@'${omm}'@g' \
              -e 's@wrapDAModeArg@'${omm}'@g' \
              -e 's@wrapAccountNumberArg@'${VFAccountNumber}'@' \
              -e 's@wrapQueueNameArg@'${VFQueueName}'@' \
              -e 's@wrapNNODEArg@'${OMMNodes}'@' \
              -e 's@wrapNPEArg@'${OMMPEPerNode}'@g' \
              ${myWrapper}.csh > ${WrapperScript}
          chmod 744 ${WrapperScript}
          ./${WrapperScript}
          @ member++
        endif
      end

#------- verify FirstCycleDate bg state ---------
      if ( ${cycle_Date} == ${FirstCycleDate} && ${doVerifyBGState} > 0 ) then
        set myWrapper = ${omm}_wrapper
        # TODO: currently depends on da to add MPASDiagVars to BG file.
        #       can do that instead with a zero-length fc_job
        set child_DependsOn=da

        set member = 1
        while ( $member <= ${nEnsDAMembers} )
          cd ${MAIN_SCRIPT_DIR}
          set VFARGS = ($CyclingDAInDirs[$member] ${CyclingDAInPrefix} ${bgDir} ${cycle_Date})

          set StateDir = $VFARGS[1]
          set memDir = `${memberDir} $DAType $member`
          set WorkDir = ${VerificationWorkDir}/$VFARGS[3]${memDir}/$VFARGS[4]

          set WrapperScript=${myWrapper}_OMB.csh
          sed -e 's@WorkDirArg@'${WorkDir}'@' \
              -e 's@JobTypeArg@'${omm}'_job@' \
              -e 's@wrapDependTypeArg@'${child_DependsOn}'@' \
              -e 's@wrapDateArg@'$VFARGS[4]'@' \
              -e 's@wrapStateDirArg@'${StateDir}'@' \
              -e 's@wrapStatePrefixArg@'$VFARGS[2]'@' \
              -e 's@wrapVARBCTableArg@'${VARBC_TABLE}'@' \
              -e 's@wrapWindowHRArg@'${CYWindowHR}'@' \
              -e 's@wrapStateTypeArg@'$VFARGS[3]'@' \
              -e 's@wrapDATypeArg@'${omm}'@g' \
              -e 's@wrapDAModeArg@'${omm}'@g' \
              -e 's@wrapAccountNumberArg@'${VFAccountNumber}'@' \
              -e 's@wrapQueueNameArg@'${VFQueueName}'@' \
              -e 's@wrapNNODEArg@'${OMMNodes}'@' \
              -e 's@wrapNPEArg@'${OMMPEPerNode}'@g' \
              ${myWrapper}.csh > ${WrapperScript}
          chmod 744 ${WrapperScript}
          ./${WrapperScript}

          @ member++
        end
      endif

#------- cycling forecast ---------
      set child_DependsOn=da
      set CyclingFCOutDirs = ()
      set member = 1
      while ( $member <= ${nEnsDAMembers} )
        cd ${MAIN_SCRIPT_DIR}
        set StateDir = $CyclingDAOutDirs[$member]
        set memDir = `${memberDir} $DAType $member`
        set WorkDir = ${CyclingFCWorkDir}/${cycle_Date}${memDir}
        set CyclingFCOutDirs = ($CyclingFCOutDirs $WorkDir)

        if ( ${doCyclingFC} > 0 ) then
          if ( $member == 1) rm ${JOBCONTROL}/last_ensfc_job
          rm -rf ${WorkDir}
          mkdir -p ${WorkDir}
          cp setup.csh ${WorkDir}/

          echo "\n${CYWindowHR}-hr cycle FC from ${cycle_Date} to ${nextDate} for member $member"
          set JobScript=${WorkDir}/fc_job_${cycle_Date}_${ExpName}.csh
          sed -e 's@icDateArg@'${cycle_Date}'@' \
              -e 's@inStateDirArg@'${StateDir}'@' \
              -e 's@inStatePrefixArg@'${CyclingDAOutPrefix}'@' \
              -e 's@fcLengthHRArg@'${CYWindowHR}'@' \
              -e 's@fcIntervalHRArg@'${CYWindowHR}'@' \
              -e 's@JobMinutes@'${CyclingFCJobMinutes}'@' \
              -e 's@AccountNumberArg@'${CYAccountNumber}'@' \
              -e 's@QueueNameArg@'${CYQueueName}'@' \
              -e 's@ExpNameArg@'${ExpName}'@' \
              fc_job.csh > ${JobScript}
          chmod 744 ${JobScript}

          cd ${WorkDir}

          set JALL=(`cat ${JOBCONTROL}/last_${child_DependsOn}_job`)
          set JDEP = ''
          foreach J ($JALL)
            if (${J} != "$nulljob" ) then
              set JDEP = ${JDEP}:${J}
            endif
          end
          set JFC = `qsub -W depend=afterok:${JDEP} ${JobScript}`
          echo "${JFC}" >> ${JOBCONTROL}/last_ensfc_job
          echo "${JFC}" > ${JOBCONTROL}/last_fc_mem${member}_job
        endif
        @ member++
      end

#------- verify forecasted bg state ---------
      set myWrapper = ${omm}_wrapper
      set VerifyBGDirs = ()

      set member = 1
      while ( $member <= ${nEnsDAMembers} )
        set VFARGS = ($CyclingFCOutDirs[$member] ${FCFilePrefix} ${bgDir} ${nextDate})
        set child_DependsOn=fc_mem${member}

        cd ${MAIN_SCRIPT_DIR}
        set StateDir = $VFARGS[1]
        set memDir = `${memberDir} $DAType $member`
        set WorkDir = ${VerificationWorkDir}/$VFARGS[3]${memDir}/$VFARGS[4]
        set VerifyBGDirs[$member] = $WorkDir

        if ( ${doVerifyBGState} > 0 ) then

          set WrapperScript=${myWrapper}_OMB.csh
          sed -e 's@WorkDirArg@'${WorkDir}'@' \
              -e 's@JobTypeArg@'${omm}'_job@' \
              -e 's@wrapDependTypeArg@'${child_DependsOn}'@' \
              -e 's@wrapDateArg@'$VFARGS[4]'@' \
              -e 's@wrapStateDirArg@'${StateDir}'@' \
              -e 's@wrapStatePrefixArg@'$VFARGS[2]'@' \
              -e 's@wrapVARBCTableArg@'${VARBC_TABLE}'@' \
              -e 's@wrapWindowHRArg@'${CYWindowHR}'@' \
              -e 's@wrapStateTypeArg@'$VFARGS[3]'@' \
              -e 's@wrapDATypeArg@'${omm}'@g' \
              -e 's@wrapDAModeArg@'${omm}'@g' \
              -e 's@wrapAccountNumberArg@'${VFAccountNumber}'@' \
              -e 's@wrapQueueNameArg@'${VFQueueName}'@' \
              -e 's@wrapNNODEArg@'${OMMNodes}'@' \
              -e 's@wrapNPEArg@'${OMMPEPerNode}'@g' \
              ${myWrapper}.csh > ${WrapperScript}
          chmod 744 ${WrapperScript}
          ./${WrapperScript}
        endif

        @ member++
      end


      if ( ${cycle_Date} == ${nextExtendedFCDate}) then
        if ( "$DAType" =~ *"eda"* ) then
          echo "WARNING: verifying forecast not enabled for EDA"
        else
          set member = 1
          set memDir = `${memberDir} $DAType $member`

          set fcWorkDir=${ExtendedFCWorkDir}/${cycle_Date}${memDir}
          set finalExtendedFCDate = `$advanceCYMDH ${cycle_Date} ${ExtendedFCWindowHR}`

#------- verification forecast ---------
          if ( ${doExtendedFC} == 0 ) then
            set child_DependsOn=da

            cd ${MAIN_SCRIPT_DIR}
            rm -rf ${fcWorkDir}
            mkdir -p ${fcWorkDir}
            cp setup.csh ${fcWorkDir}/

            set StateDir = $CyclingDAOutDirs[$member]

            echo "\n${ExtendedFCWindowHR}-hr verification FC from ${cycle_Date} to ${finalExtendedFCDate}"
            set JobScript=${fcWorkDir}/fcvf_job_${cycle_Date}_${ExpName}.csh
            sed -e 's@icDateArg@'${cycle_Date}'@' \
                -e 's@inStateDirArg@'${StateDir}'@' \
                -e 's@inStatePrefixArg@'${CyclingDAOutPrefix}'@' \
                -e 's@fcLengthHRArg@'${ExtendedFCWindowHR}'@' \
                -e 's@fcIntervalHRArg@'${ExtendedFC_DT_HR}'@' \
                -e 's@JobMinutes@'${ExtendedFCJobMinutes}'@' \
                -e 's@AccountNumberArg@'${CYAccountNumber}'@' \
                -e 's@QueueNameArg@'${CYQueueName}'@' \
                -e 's@ExpNameArg@'${ExpName}'@' \
                fc_job.csh > ${JobScript}
            chmod 744 ${JobScript}

            cd ${fcWorkDir}

            set JALL=(`cat ${JOBCONTROL}/last_${child_DependsOn}_job`)
            set JDEP = ''
            foreach J ($JALL)
              if (${J} != "$nulljob" ) then
                set JDEP = ${JDEP}:${J}
              endif
            end
            set JExtendedFC = `qsub -W depend=afterok:${JDEP} ${JobScript}`
            echo "${JExtendedFC}" > ${JOBCONTROL}/last_fcvf_mem${member}_job
          endif

#------- verify fc state(s) ---------
          if ( ${doVerifyFCState} == 0 ) then
            set child_DependsOn=fcvf_mem${member}
            set myWrapper = ${omm}_wrapper

            set VFARGS = (${fcWorkDir} ${FCFilePrefix} ${fcDir} ${cycle_Date})
            set StateDir = $VFARGS[1]
            set dateWorkDir = ${VerificationWorkDir}/$VFARGS[3]${memDir}/$VFARGS[4]
            mkdir -p ${dateWorkDir}

            cd ${MAIN_SCRIPT_DIR}

            @ dt = 0
            while ( $VFARGS[4] <= ${finalExtendedFCDate} )
              set WorkDir = $dateWorkDir/${dt}hr
              if ( $dt == 0 )  then
                ## 0 hour fc length same as analysis (requires previous VerifyANState)
                rm -r ${WorkDir}
                ln -sf $VerifyANDirs[$member] ${WorkDir}
              else if ( ${dt} == ${CYWindowHR} ) then
                ## CYWindowHR fc length same as background (requires previous VerifyBGState)
                rm -r ${WorkDir}
                ln -sf $VerifyBGDirs[$member] ${WorkDir}
              else
                set WrapperScript=${myWrapper}_OMF.csh
                sed -e 's@WorkDirArg@'${WorkDir}'@' \
                    -e 's@JobTypeArg@'${omm}'_job@' \
                    -e 's@wrapDependTypeArg@'${child_DependsOn}'@' \
                    -e 's@wrapDateArg@'$VFARGS[4]'@' \
                    -e 's@wrapStateDirArg@'${StateDir}'@' \
                    -e 's@wrapStatePrefixArg@'$VFARGS[2]'@' \
                    -e 's@wrapVARBCTableArg@'${VARBC_TABLE}'@' \
                    -e 's@wrapWindowHRArg@'${DAVFWindowHR}'@' \
                    -e 's@wrapStateTypeArg@'$VFARGS[3]'@' \
                    -e 's@wrapDATypeArg@'${omm}'@g' \
                    -e 's@wrapDAModeArg@'${omm}'@g' \
                    -e 's@wrapAccountNumberArg@'${VFAccountNumber}'@' \
                    -e 's@wrapQueueNameArg@'${VFQueueName}'@' \
                    -e 's@wrapNNODEArg@'${OMMNodes}'@' \
                    -e 's@wrapNPEArg@'${OMMPEPerNode}'@g' \
                    ${myWrapper}.csh > ${WrapperScript}
                chmod 744 ${WrapperScript}
                ./${WrapperScript}
              endif

              set VFARGS[4] = `$advanceCYMDH $VFARGS[4] ${ExtendedFC_DT_HR}`
              @ dt = $dt + $ExtendedFC_DT_HR
            end
          endif
        endif

        set nextExtendedFCDate = `$advanceCYMDH ${nextExtendedFCDate} ${ExtendedFC_INTERVAL_HR}`
      endif

      cd ${MAIN_SCRIPT_DIR}

#------- advance date ---------
      set cycle_Date = `$advanceCYMDH ${cycle_Date} ${CYWindowHR}`
      setenv cycle_Date ${cycle_Date}
    end

    exit 0
