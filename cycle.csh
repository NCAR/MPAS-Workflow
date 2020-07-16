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
    echo "$nulljob" > ${JOBCONTROL}/ensfc
    set member = 1
    while ( $member <= ${nEnsDAMembers} )
      echo "$nulljob" > ${JOBCONTROL}/fc_mem${member}
      echo "$nulljob" > ${JOBCONTROL}/fcvf_mem${member}
      @ member++
    end
    echo "$nulljob" > ${JOBCONTROL}/da
    echo "$nulljob" > ${JOBCONTROL}/omm
    echo "$nulljob" > ${JOBCONTROL}/null

    ## workflow component selection
    set doCyclingDA = 1
    #TODO: enable mean state diagnostics; only work for deterministic DA
    set doDiagnoseMeanOMB = 0
    set doDiagnoseMeanBG = 0

    set doOMA = 1
    set doDiagnoseOMA = 1
    set doDiagnoseAN = 1

    set doCyclingFC = 1
    set doOMB = 1
    set doDiagnoseOMB = 1
    set doDiagnoseBG = 1

    set doExtendedFC = 0
    set doOMF = 0
    set doDiagnoseOMF = 0
    set doDiagnoseFC = 0

    # TODO(JJG): add forceIFExists or skipIFExists
    #            flags for individual
    #            DA/FC/OMM/VF stages

#
# 2, CYCLE:
# =========

    echo "==============================================================\n"
    echo "Cycling workflow for experiment: ${ExpName}\n"
    echo "==============================================================\n"

    set CyclingDAInPrefix = ${BGFilePrefix}
    set CyclingDAOutPrefix = ${ANFilePrefix}

    ## cycling
    setenv cycle_Date ${ExpStartDate}  # initialize cycling date
    while ( ${cycle_Date} <= ${ExpEndDate} )
      set prevDate = `$advanceCYMDH ${cycle_Date} -${CYWindowHR}`
      set nextDate = `$advanceCYMDH ${cycle_Date} ${CYWindowHR}`
      setenv prevDate ${prevDate}
      setenv nextDate ${nextDate}

      ## setup cycle directory names
      set CyclingDADir = ${CyclingDAWorkDir}/${cycle_Date}
      set prevCyclingDADir = ${CyclingDAWorkDir}/${prevDate}
      set CyclingFCDir = ${CyclingFCWorkDir}/${cycle_Date}
      set prevCyclingFCDir = ${CyclingFCWorkDir}/${prevDate}
      set ExtendedFCDir = ${ExtendedFCWorkDir}/${cycle_Date}

      set CyclingDAInDirs = ()
      set CyclingDAOutDirs = ()
      set CyclingFCDirs = ()
      set prevCyclingFCDirs = ()
      set ExtendedFCDirs = ()

      set VerifyBGDirs = ()
      set VerifyANDirs = ()
      set VerifyFirstBGDirs = ()
      set VerifyFCDirs = ()

      set member = 1
      while ( $member <= ${nEnsDAMembers} )
        set memDir = `${memberDir} $DAType $member`
        set CyclingDAInDirs[$member] = ${CyclingDADir}/${bgDir}${memDir}
        set CyclingDAOutDirs[$member] = ${CyclingDADir}/${anDir}${memDir}
        set CyclingFCDirs[$member] = ${CyclingFCDir}${memDir}
        set prevCyclingFCDirs[$member] = ${prevCyclingFCDir}${memDir}
        set ExtendedFCDirs[$member] = ${ExtendedFCDir}${memDir}

        set VerifyANDirs[$member] = ${VerificationWorkDir}/${anDir}${memDir}/${cycle_Date}
        set VerifyBGDirs[$member] = ${VerificationWorkDir}/${bgDir}${memDir}/${nextDate}
        set VerifyFirstBGDirs[$member] = ${VerificationWorkDir}/${bgDir}${memDir}/${cycle_Date}
        set VerifyFCDirs[$member] = ${VerificationWorkDir}/${fcDir}${memDir}/${cycle_Date}
        @ member++
      end


      ## First cycle "forecast" established offline
      # TODO: make FirstCycleDate behavior part of CyclingFC or seperate application
      #       instead of top-level workflow using zero-length fc_job
      if ( ${cycle_Date} == ${FirstCycleDate} ) then
        mkdir -p ${CyclingFCWorkDir}
        rm -r ${prevCyclingFCDir}
        set member = 1
        while ( $member <= ${nEnsDAMembers} )
          if ( "$DAType" =~ *"eda"* ) then
            mkdir ${prevCyclingFCDir}
            set InitialFC = "$ensembleICFirstCycle"`${memberDir} ens $member "${fixedEnsMemFmt}"`
          else
            set InitialFC = $deterministicICFirstCycle
          endif
          ln -sf ${InitialFC} $prevCyclingFCDirs[$member]

          @ member++
        end
        setenv VARBC_TABLE ${INITIAL_VARBC_TABLE}
        setenv bgStatePrefix ${RSTFilePrefix}
      else
        setenv VARBC_TABLE ${prevCyclingDADir}/${VARBC_ANA}
        setenv bgStatePrefix ${FCFilePrefix}
      endif

      echo "\nWorking on cycle: ${cycle_Date}"

#------- cycling DA ---------
      set WorkDir = ${CyclingDADir}
      set child_DependsOn=ensfc

      set doJobs = ($doCyclingDA $doDiagnoseMeanOMB $doDiagnoseMeanBG)
      set active = 0
      foreach activate ($doJobs)
        @ active = $active + $activate
      end

      if ( $active > 0 ) then
        set myWrapper = jobANDverify
        set WrapperScript=${myWrapper}_CyclingDA.csh
        sed -e 's@WorkDirArg@'${WorkDir}'@' \
            -e 's@JobNameArg@da_job@' \
            -e 's@DependTypeArg@'${child_DependsOn}'@' \
            -e 's@wrapDateArg@'${cycle_Date}'@' \
            -e 's@wrapStateDirsArg@'$prevCyclingFCDirs'@' \
            -e 's@wrapStatePrefixArg@'${bgStatePrefix}'@' \
            -e 's@wrapStateTypeArg@bg@' \
            -e 's@wrapVARBCTableArg@'${VARBC_TABLE}'@' \
            -e 's@wrapWindowHRArg@'${CYWindowHR}'@' \
            -e 's@wrapDATypeArg@'${DAType}'@g' \
            -e 's@wrapDAModeArg@da@g' \
            -e 's@wrapAccountNumberArg@'${CYAccountNumber}'@' \
            -e 's@wrapQueueNameArg@'${CYQueueName}'@' \
            -e 's@wrapNNODEArg@'${CyclingDANodes}'@' \
            -e 's@wrapNPEArg@'${CyclingDAPEPerNode}'@g' \
            ${myWrapper}.csh > ${WrapperScript}
        chmod 744 ${WrapperScript}
        ./${WrapperScript}

        cd ${WorkDir}
        # TODO: replace this job control with automatic creation of cylc suite.rc file
        set JobScripts=(`cat JobScripts`)
        set JobTypes=(`cat JobTypes`)
        set JobDependencies=(`cat JobDependencies`)
        set i = 1
        while ($i < ${#JobScripts})
          if ( $doJobs[$i] == 1 && "$Script" != "None" ) then
            set JALL=(`cat ${JOBCONTROL}/$JobDependencies[$i]`)
            set JDEP = ''
            foreach J ($JALL)
              if (${J} != "$nulljob" ) set JDEP = ${JDEP}:${J}
            end
            set J = `qsub -W depend=afterok${JDEP} $JobScripts[$i]`
            echo "${J}" > ${JOBCONTROL}/$JobTypes[$i]
          endif
          @ i++
        end
      endif

#------- verify analysis state ---------
      set myWrapper = jobANDverify
      set doJobs = ($doOMA $doDiagnoseOMA $doDiagnoseAN)
      set active = 0
      foreach activate ($doJobs)
        @ active = $active + $activate
      end

      set child_DependsOn=da
      set member = 1
      while ( $member <= ${nEnsDAMembers} )
        cd ${MAIN_SCRIPT_DIR}
        set child_ARGS = ($CyclingDAOutDirs[$member] ${CyclingDAOutPrefix} ${anDir} ${cycle_Date} ${CYWindowHR})
        set WorkDir = $VerifyANDirs[$member]
        @ member++

        if ( $active == 0 ) continue

        set WrapperScript=${myWrapper}_OMA.csh
        sed -e 's@WorkDirArg@'${WorkDir}'@' \
            -e 's@JobNameArg@'${omm}'_job@' \
            -e 's@DependTypeArg@'${child_DependsOn}'@' \
            -e 's@wrapDateArg@'$child_ARGS[4]'@' \
            -e 's@wrapStateDirsArg@'$child_ARGS[1]'@' \
            -e 's@wrapStatePrefixArg@'$child_ARGS[2]'@' \
            -e 's@wrapStateTypeArg@'$child_ARGS[3]'@' \
            -e 's@wrapVARBCTableArg@'${VARBC_TABLE}'@' \
            -e 's@wrapWindowHRArg@'$child_ARGS[5]'@' \
            -e 's@wrapDATypeArg@'${omm}'@g' \
            -e 's@wrapDAModeArg@'${omm}'@g' \
            -e 's@wrapAccountNumberArg@'${VFAccountNumber}'@' \
            -e 's@wrapQueueNameArg@'${VFQueueName}'@' \
            -e 's@wrapNNODEArg@'${OMMNodes}'@' \
            -e 's@wrapNPEArg@'${OMMPEPerNode}'@g' \
            ${myWrapper}.csh > ${WrapperScript}
        chmod 744 ${WrapperScript}
        ./${WrapperScript}

        cd ${WorkDir}
        set JobScripts=(`cat JobScripts`)
        set JobTypes=(`cat JobTypes`)
        set JobDependencies=(`cat JobDependencies`)
        set i = 1
        while ($i < ${#JobScripts})
          if ( $doJobs[$i] == 1 && "$Script" != "None" ) then
            set JALL=(`cat ${JOBCONTROL}/$JobDependencies[$i]`)
            set JDEP = ''
            foreach J ($JALL)
              if (${J} != "$nulljob" ) set JDEP = ${JDEP}:${J}
            end
            set J = `qsub -W depend=afterok${JDEP} $JobScripts[$i]`
            echo "${J}" > ${JOBCONTROL}/$JobTypes[$i]
          endif
          @ i++
        end
      end

#------- verify FirstCycleDate bg state ---------
      if ( ${cycle_Date} == ${FirstCycleDate} ) then
        # TODO: somehow replace this w/ generalized VerifyBG below
        set myWrapper = jobANDverify
        set doJobs = ($doOMB $doDiagnoseOMB $doDiagnoseBG)
        set active = 0
        foreach activate ($doJobs)
          @ active = $active + $activate
        end

        set child_DependsOn=da
        set member = 1
        while ( $member <= ${nEnsDAMembers} )
          cd ${MAIN_SCRIPT_DIR}
          set child_ARGS = ($CyclingDAInDirs[$member] ${CyclingDAInPrefix} ${bgDir} ${cycle_Date} ${CYWindowHR})
          set WorkDir = $VerifyFirstBGDirs[$member]
          @ member++

          if ( $active == 0 ) continue

          set WrapperScript=${myWrapper}_OMB.csh
          sed -e 's@WorkDirArg@'${WorkDir}'@' \
              -e 's@JobNameArg@'${omm}'_job@' \
              -e 's@DependTypeArg@'${child_DependsOn}'@' \
              -e 's@wrapDateArg@'$child_ARGS[4]'@' \
              -e 's@wrapStateDirsArg@'$child_ARGS[1]'@' \
              -e 's@wrapStatePrefixArg@'$child_ARGS[2]'@' \
              -e 's@wrapStateTypeArg@'$child_ARGS[3]'@' \
              -e 's@wrapVARBCTableArg@'${VARBC_TABLE}'@' \
              -e 's@wrapWindowHRArg@'$child_ARGS[5]'@' \
              -e 's@wrapDATypeArg@'${omm}'@g' \
              -e 's@wrapDAModeArg@'${omm}'@g' \
              -e 's@wrapAccountNumberArg@'${VFAccountNumber}'@' \
              -e 's@wrapQueueNameArg@'${VFQueueName}'@' \
              -e 's@wrapNNODEArg@'${OMMNodes}'@' \
              -e 's@wrapNPEArg@'${OMMPEPerNode}'@g' \
              ${myWrapper}.csh > ${WrapperScript}
          chmod 744 ${WrapperScript}
          ./${WrapperScript}

          cd ${WorkDir}
          set JobScripts=(`cat JobScripts`)
          set JobTypes=(`cat JobTypes`)
          set JobDependencies=(`cat JobDependencies`)
          set i = 1
          while ($i < ${#JobScripts})
            if ( $doJobs[$i] == 1 && "$Script" != "None" ) then
              set JALL=(`cat ${JOBCONTROL}/$JobDependencies[$i]`)
              set JDEP = ''
              foreach J ($JALL)
                if (${J} != "$nulljob" ) set JDEP = ${JDEP}:${J}
              end
              set J = `qsub -W depend=afterok${JDEP} $JobScripts[$i]`
              echo "${J}" > ${JOBCONTROL}/$JobTypes[$i]
            endif
            @ i++
          end
        end
      endif

#------- cycling forecast ---------
      set child_DependsOn=da
      set member = 1
      while ( $member <= ${nEnsDAMembers} )
        set WorkDir = $CyclingFCDirs[$member]

        if ( ${doCyclingFC} > 0 ) then
          if ( $member == 1) rm ${JOBCONTROL}/ensfc
          rm -rf ${WorkDir}
          mkdir -p ${WorkDir}
          echo "\n${CYWindowHR}-hr cycle FC from ${cycle_Date} to ${nextDate} for member $member"

          cd ${MAIN_SCRIPT_DIR}
          cp setup.csh ${WorkDir}/
          set JobScript=${WorkDir}/fc_job_${cycle_Date}_${ExpName}.csh
          sed -e 's@icDateArg@'${cycle_Date}'@' \
              -e 's@inStateDirArg@'$CyclingDAOutDirs[$member]'@' \
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

          set JALL=(`cat ${JOBCONTROL}/${child_DependsOn}`)
          set JDEP = ''
          foreach J ($JALL)
            if (${J} != "$nulljob" ) then
              set JDEP = ${JDEP}:${J}
            endif
          end
          set JFC = `qsub -W depend=afterok:${JDEP} ${JobScript}`
          echo "${JFC}" >> ${JOBCONTROL}/ensfc
          echo "${JFC}" > ${JOBCONTROL}/fc_mem${member}
        endif
        @ member++
      end

#------- verify forecasted bg state ---------
      set myWrapper = jobANDverify
      set doJobs = ($doOMB $doDiagnoseOMB $doDiagnoseBG)
      foreach activate ($doJobs)
        @ active = $active + $activate
      end

      set VerifyBGDirs = ()
      set member = 1
      while ( $member <= ${nEnsDAMembers} )
        set child_ARGS = ($CyclingFCDirs[$member] ${FCFilePrefix} ${bgDir} ${nextDate} ${CYWindowHR})
        set child_DependsOn=fc_mem${member}

        cd ${MAIN_SCRIPT_DIR}
        set WorkDir = $VerifyBGDirs[$member]
        @ member++

        if ( $active == 0 ) continue

        set WrapperScript=${myWrapper}_OMB.csh
        sed -e 's@WorkDirArg@'${WorkDir}'@' \
            -e 's@JobNameArg@'${omm}'_job@' \
            -e 's@DependTypeArg@'${child_DependsOn}'@' \
            -e 's@wrapDateArg@'$child_ARGS[4]'@' \
            -e 's@wrapStateDirsArg@'$child_ARGS[1]'@' \
            -e 's@wrapStatePrefixArg@'$child_ARGS[2]'@' \
            -e 's@wrapStateTypeArg@'$child_ARGS[3]'@' \
            -e 's@wrapVARBCTableArg@'${VARBC_TABLE}'@' \
            -e 's@wrapWindowHRArg@'$child_ARGS[5]'@' \
            -e 's@wrapDATypeArg@'${omm}'@g' \
            -e 's@wrapDAModeArg@'${omm}'@g' \
            -e 's@wrapAccountNumberArg@'${VFAccountNumber}'@' \
            -e 's@wrapQueueNameArg@'${VFQueueName}'@' \
            -e 's@wrapNNODEArg@'${OMMNodes}'@' \
            -e 's@wrapNPEArg@'${OMMPEPerNode}'@g' \
            ${myWrapper}.csh > ${WrapperScript}
        chmod 744 ${WrapperScript}
        ./${WrapperScript}

        cd ${WorkDir}
        ${SubmitWrapperJobs}
        set JobScripts=(`cat JobScripts`)
        set JobTypes=(`cat JobTypes`)
        set JobDependencies=(`cat JobDependencies`)
        set i = 1
        while ($i < ${#JobScripts})
          if ( $doJobs[$i] == 1 && "$Script" != "None" ) then
            set JALL=(`cat ${JOBCONTROL}/$JobDependencies[$i]`)
            set JDEP = ''
            foreach J ($JALL)
              if (${J} != "$nulljob" ) set JDEP = ${JDEP}:${J}
            end
            set J = `qsub -W depend=afterok${JDEP} $JobScripts[$i]`
            echo "${J}" > ${JOBCONTROL}/$JobTypes[$i]
          endif
          @ i++
        end
      end

      ## determine next ExtendedFC date on or after cycle_Date
      set nextExtendedFCDate = ${FirstCycleDate}
      while ( ${nextExtendedFCDate} < ${cycle_Date} )
        set nextExtendedFCDate = `$advanceCYMDH ${nextExtendedFCDate} ${ExtendedFC_INTERVAL_HR}`
      end
      if ( ${cycle_Date} == ${nextExtendedFCDate}) then
        if ( "$DAType" =~ *"eda"* ) then
          echo "WARNING: extended forecast not enabled for EDA"
        else
          set member = 1

#------- verification forecast ---------
          if ( ${doExtendedFC} == 0 ) then
            set child_DependsOn=da
            rm -rf $ExtendedFCDirs[$member]
            mkdir -p $ExtendedFCDirs[$member]

            set finalExtendedFCDate = `$advanceCYMDH ${cycle_Date} ${ExtendedFCWindowHR}`
            echo "\n${ExtendedFCWindowHR}-hr verification FC from ${cycle_Date} to ${finalExtendedFCDate}"

            cd ${MAIN_SCRIPT_DIR}
            cp setup.csh $ExtendedFCDirs[$member]/
            set JobScript=$ExtendedFCDirs[$member]/fcvf_job_${cycle_Date}_${ExpName}.csh
            sed -e 's@icDateArg@'${cycle_Date}'@' \
                -e 's@inStateDirArg@'$CyclingDAOutDirs[$member]'@' \
                -e 's@inStatePrefixArg@'${CyclingDAOutPrefix}'@' \
                -e 's@fcLengthHRArg@'${ExtendedFCWindowHR}'@' \
                -e 's@fcIntervalHRArg@'${ExtendedFC_DT_HR}'@' \
                -e 's@JobMinutes@'${ExtendedFCJobMinutes}'@' \
                -e 's@AccountNumberArg@'${CYAccountNumber}'@' \
                -e 's@QueueNameArg@'${CYQueueName}'@' \
                -e 's@ExpNameArg@'${ExpName}'@' \
                fc_job.csh > ${JobScript}
            chmod 744 ${JobScript}

            cd $ExtendedFCDirs[$member]

            set JALL=(`cat ${JOBCONTROL}/${child_DependsOn}`)
            set JDEP = ''
            foreach J ($JALL)
              if (${J} != "$nulljob" ) then
                set JDEP = ${JDEP}:${J}
              endif
            end
            set JExtendedFC = `qsub -W depend=afterok:${JDEP} ${JobScript}`
            echo "${JExtendedFC}" > ${JOBCONTROL}/fcvf_mem${member}
          endif


#------- verify fc state(s) ---------
          set child_DependsOn=fcvf_mem${member}
          set myWrapper = jobANDverify

          set doJobs = ($doOMF $doDiagnoseOMF $doDiagnoseFC)
          set active = 0
          foreach activate ($doJobs)
            @ active = $active + $activate
          end

          set child_ARGS = ($ExtendedFCDirs[$member] ${FCFilePrefix} ${fcDir} ${cycle_Date} ${DAVFWindowHR})
          mkdir -p $VerifyFCDirs[$member]

          @ dt = 0
          while ( $dt <= ${ExtendedFCWindowHR} )
            set WorkDir = $VerifyFCDirs[$member]/${dt}hr
#NOTE: AN and BG verification use different windows for OMB/OMA, but
#      they are identical to FC verification in the model-space
#            if ( $dt == 0 )  then
#              ## 0 hour fc length same as analysis (requires previous DiagnoseOMA/AN)
#              rm -r ${WorkDir}
#              ln -sf $VerifyANDirs[$member] ${WorkDir}
#            else if ( ${dt} == ${CYWindowHR} ) then
#              ## CYWindowHR fc length same as background (requires previous DiagnoseOMB/BG)
#              rm -r ${WorkDir}
#              ln -sf $VerifyBGDirs[$member] ${WorkDir}
#            else if ( $active > 0 ) then
            if ( $active > 0 ) then
              cd ${MAIN_SCRIPT_DIR}
              set WrapperScript=${myWrapper}_OMF.csh
              sed -e 's@WorkDirArg@'${WorkDir}'@' \
                  -e 's@JobNameArg@'${omm}'_job@' \
                  -e 's@DependTypeArg@'${child_DependsOn}'@' \
                  -e 's@wrapDateArg@'$child_ARGS[4]'@' \
                  -e 's@wrapStateDirsArg@'$child_ARGS[1]'@' \
                  -e 's@wrapStatePrefixArg@'$child_ARGS[2]'@' \
                  -e 's@wrapStateTypeArg@'$child_ARGS[3]'@' \
                  -e 's@wrapVARBCTableArg@'${VARBC_TABLE}'@' \
                  -e 's@wrapWindowHRArg@'$child_ARGS[5]'@' \
                  -e 's@wrapDATypeArg@'${omm}'@g' \
                  -e 's@wrapDAModeArg@'${omm}'@g' \
                  -e 's@wrapAccountNumberArg@'${VFAccountNumber}'@' \
                  -e 's@wrapQueueNameArg@'${VFQueueName}'@' \
                  -e 's@wrapNNODEArg@'${OMMNodes}'@' \
                  -e 's@wrapNPEArg@'${OMMPEPerNode}'@g' \
                  ${myWrapper}.csh > ${WrapperScript}
              chmod 744 ${WrapperScript}
              ./${WrapperScript}

              cd ${WorkDir}
              set JobScripts=(`cat JobScripts`)
              set JobTypes=(`cat JobTypes`)
              set JobDependencies=(`cat JobDependencies`)
              set i = 1
              while ($i < ${#JobScripts})
                if ( $doJobs[$i] == 1 && "$Script" != "None" ) then
                  set JALL=(`cat ${JOBCONTROL}/$JobDependencies[$i]`)
                  set JDEP = ''
                  foreach J ($JALL)
                    if (${J} != "$nulljob" ) set JDEP = ${JDEP}:${J}
                  end
                  set J = `qsub -W depend=afterok${JDEP} $JobScripts[$i]`
                  echo "${J}" > ${JOBCONTROL}/$JobTypes[$i]
                endif
                @ i++
              end
            endif

            @ dt = $dt + $ExtendedFC_DT_HR
            set child_ARGS[4] = `$advanceCYMDH ${cycle_Date} $dt`
          end
        endif
      endif

      cd ${MAIN_SCRIPT_DIR}

#------- advance date ---------
      set cycle_Date = `$advanceCYMDH ${cycle_Date} ${CYWindowHR}`
      setenv cycle_Date ${cycle_Date}
    end

    exit 0
