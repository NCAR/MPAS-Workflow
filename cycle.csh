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
      echo "$nulljob" > ${JOBCONTROL}/exfc_mem${member}
      @ member++
    end
    echo "$nulljob" > ${JOBCONTROL}/da_job
    echo "$nulljob" > ${JOBCONTROL}/omm_job

    ## workflow component selection
    set doCyclingDA = 1
    #TODO: enable mean state diagnostics; only work for deterministic DA
    set doDiagnoseMeanOMB = 0
    set doDiagnoseMeanBG = 0

    set doOMA = 0
    set doDiagnoseOMA = 0
    set doDiagnoseAN = 0

    set doCyclingFC = 1
    set doOMB = 0
    set doDiagnoseOMB = 0
    set doDiagnoseBG = 0

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

    ## cycling
    setenv cycle_Date ${ExpStartDate}  # initialize cycling date
    while ( ${cycle_Date} <= ${ExpEndDate} )
      source ${MAIN_SCRIPT_DIR}/setupCycleNames.csh

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

#------- CyclingDA ---------
      set WorkDir = ${CyclingDADir}
      set child_DependsOn=ensfc

      set doJobs = ($doCyclingDA $doDiagnoseMeanOMB $doDiagnoseMeanBG)
      set active = 0
      foreach activate ($doJobs)
        @ active = $active + $activate
      end

      if ( $active > 0 ) then
        cd ${MAIN_SCRIPT_DIR}
        set myWrapper = appANDverify
        set WrapperScript=${MAIN_SCRIPT_DIR}/${myWrapper}_CyclingDA.csh
        sed -e 's@WorkDirArg@'${WorkDir}'@' \
            -e 's@JobNameArg@da_job@' \
            -e 's@DependTypeArg@'${child_DependsOn}'@' \
            -e 's@wrapDateArg@'${cycle_Date}'@' \
            -e 's@wrapStateDirArg@'${prevCyclingFCDir}'@' \
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
            ${MAIN_SCRIPT_DIR}/${myWrapper}.csh > ${WrapperScript}
        chmod 744 ${WrapperScript}
        ${WrapperScript}

        cd ${WorkDir}
        # TODO: replace this job control with automatic creation of cylc suite.rc file
        set JobScripts=(`cat JobScripts`)
        set JobTypes=(`cat JobTypes`)
        set JobDependencies=(`cat JobDependencies`)
        set i = 1
        while ($i < ${#JobScripts})
          set JobScript = "$JobScripts[$i]"
          if ( $doJobs[$i] == 1 && "$JobScript" != "None" ) then
            set JALL=(`cat ${JOBCONTROL}/$JobDependencies[$i]`)
            set JDEP = "${DEPSTART}"
            foreach J ($JALL)
              if (${J} != "$nulljob" ) set JDEP = ${JDEP}"${DEPSEP}"${J}
            end
            if ($JDEP != "") set JDEP = "${DEPEND}"${JDEP}
            set J = `${SUBMIT} ${JDEP} $JobScript`
            if ($SUBMIT == sbatch) set J = `echo $J | sed 's@Submitted batch job @@'`
            echo "${J}" > ${JOBCONTROL}/$JobTypes[$i]
          endif
          @ i++
        end
      endif


#------- VerifyAN ---------
      set myWrapper = appANDverify
      set doJobs = ($doOMA $doDiagnoseOMA $doDiagnoseAN)
      set active = 0
      foreach activate ($doJobs)
        @ active = $active + $activate
      end

      set child_DependsOn=da_job
      set member = 1
      while ( $member <= ${nEnsDAMembers} )
        set child_ARGS = ($CyclingDAOutDirs[$member] ${ANFilePrefix} ${anDir} ${cycle_Date} ${CYWindowHR})
        set WorkDir = $VerifyANDirs[$member]
        @ member++

        if ( $active == 0 ) continue

        cd ${MAIN_SCRIPT_DIR}
        set WrapperScript=${MAIN_SCRIPT_DIR}/${myWrapper}_OMA.csh
        sed -e 's@WorkDirArg@'${WorkDir}'@' \
            -e 's@JobNameArg@'${omm}'_job@' \
            -e 's@DependTypeArg@'${child_DependsOn}'@' \
            -e 's@wrapDateArg@'$child_ARGS[4]'@' \
            -e 's@wrapStateDirArg@'$child_ARGS[1]'@' \
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
            ${MAIN_SCRIPT_DIR}/${myWrapper}.csh > ${WrapperScript}
        chmod 744 ${WrapperScript}
        ${WrapperScript}

        cd ${WorkDir}
        set JobScripts=(`cat JobScripts`)
        set JobTypes=(`cat JobTypes`)
        set JobDependencies=(`cat JobDependencies`)
        set i = 1
        while ($i < ${#JobScripts})
          set JobScript = "$JobScripts[$i]"
          if ( $doJobs[$i] == 1 && "$JobScript" != "None" ) then
            set JALL=(`cat ${JOBCONTROL}/$JobDependencies[$i]`)
            set JDEP = "${DEPSTART}"
            foreach J ($JALL)
              if (${J} != "$nulljob" ) set JDEP = ${JDEP}"${DEPSEP}"${J}
            end
            if ($JDEP != "") set JDEP = "${DEPEND}"${JDEP}
            set J = `${SUBMIT} "${JDEP}" $JobScript`
            if ($SUBMIT == sbatch) set J = `echo $J | sed 's@Submitted batch job @@'`
            echo "${J}" > ${JOBCONTROL}/$JobTypes[$i]
          endif
          @ i++
        end
      end

#------- VerifyBG at FirstCycleDate ---------
      if ( ${cycle_Date} == ${FirstCycleDate} ) then
        # TODO: somehow replace this w/ generalized VerifyBG below
        set myWrapper = appANDverify
        set doJobs = ($doOMB $doDiagnoseOMB $doDiagnoseBG)
        set active = 0
        foreach activate ($doJobs)
          @ active = $active + $activate
        end

        set child_DependsOn=da_job
        set member = 1
        while ( $member <= ${nEnsDAMembers} )
          set WorkDir = $VerifyFirstBGDirs[$member]
          set child_ARGS = ($CyclingDAInDirs[$member] ${BGFilePrefix} ${bgDir} ${cycle_Date} ${CYWindowHR})
          @ member++

          if ( $active == 0 ) continue

          cd ${MAIN_SCRIPT_DIR}
          set WrapperScript=${MAIN_SCRIPT_DIR}/${myWrapper}_OMB.csh
          sed -e 's@WorkDirArg@'${WorkDir}'@' \
              -e 's@JobNameArg@'${omm}'_job@' \
              -e 's@DependTypeArg@'${child_DependsOn}'@' \
              -e 's@wrapDateArg@'$child_ARGS[4]'@' \
              -e 's@wrapStateDirArg@'$child_ARGS[1]'@' \
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
              ${MAIN_SCRIPT_DIR}/${myWrapper}.csh > ${WrapperScript}
          chmod 744 ${WrapperScript}
          ${WrapperScript}

          cd ${WorkDir}
          set JobScripts=(`cat JobScripts`)
          set JobTypes=(`cat JobTypes`)
          set JobDependencies=(`cat JobDependencies`)
          set i = 1
          while ($i < ${#JobScripts})
            set JobScript = "$JobScripts[$i]"
            if ( $doJobs[$i] == 1 && "$JobScript" != "None" ) then
              set JALL=(`cat ${JOBCONTROL}/$JobDependencies[$i]`)
              set JDEP = "${DEPSTART}"
              foreach J ($JALL)
                if (${J} != "$nulljob" ) set JDEP = ${JDEP}"${DEPSEP}"${J}
              end
              if ($JDEP != "") set JDEP = "${DEPEND}"${JDEP}
              set J = `${SUBMIT} "${JDEP}" $JobScript`
              if ($SUBMIT == sbatch) set J = `echo $J | sed 's@Submitted batch job @@'`
              echo "${J}" > ${JOBCONTROL}/$JobTypes[$i]
            endif
            @ i++
          end
        end
      endif

#------- CyclingFC ---------
      set child_DependsOn=da_job
      set member = 1
      while ( $member <= ${nEnsDAMembers} )
        set WorkDir = $CyclingFCDirs[$member]

        if ( ${doCyclingFC} > 0 ) then
          if ( $member == 1) rm ${JOBCONTROL}/ensfc
          rm -rf ${WorkDir}
          mkdir -p ${WorkDir}
          echo "\n${CYWindowHR}-hr cycle FC from ${cycle_Date} to ${nextDate} for member $member"

          cd ${MAIN_SCRIPT_DIR}
          ln -sf ${MAIN_SCRIPT_DIR}/setup.csh ${WorkDir}/
          set JobScript=${WorkDir}/fc_job.csh
          sed -e 's@inDateArg@'${cycle_Date}'@' \
              -e 's@inStateDirArg@'$CyclingDAOutDirs[$member]'@' \
              -e 's@inStatePrefixArg@'${ANFilePrefix}'@' \
              -e 's@fcLengthHRArg@'${CYWindowHR}'@' \
              -e 's@fcIntervalHRArg@'${CYWindowHR}'@' \
              -e 's@JobMinutesArg@'${CyclingFCJobMinutes}'@' \
              -e 's@AccountNumberArg@'${CYAccountNumber}'@' \
              -e 's@QueueNameArg@'${CYQueueName}'@' \
              -e 's@ExpNameArg@'${ExpName}'@' \
              ${MAIN_SCRIPT_DIR}/fc_job.csh > ${JobScript}
          chmod 744 ${JobScript}

          cd ${WorkDir}

          set JALL=(`cat ${JOBCONTROL}/${child_DependsOn}`)
          set JDEP = "${DEPSTART}"
          foreach J ($JALL)
            if (${J} != "$nulljob" ) then
              set JDEP = ${JDEP}"${DEPSEP}"${J}
            endif
          end
          if ($JDEP != "") set JDEP = "${DEPEND}"${JDEP}
          set J = `${SUBMIT} "${JDEP}" ${JobScript}`
          if ($SUBMIT == sbatch) set J = `echo $J | sed 's@Submitted batch job @@'`
          echo "${J}" >> ${JOBCONTROL}/ensfc
          echo "${J}" > ${JOBCONTROL}/fc_mem${member}
        endif
        @ member++
      end

exit


#------- VerifyBG ---------
      set myWrapper = appANDverify
      set doJobs = ($doOMB $doDiagnoseOMB $doDiagnoseBG)
      foreach activate ($doJobs)
        @ active = $active + $activate
      end

      set member = 1
      while ( $member <= ${nEnsDAMembers} )
        set WorkDir = $VerifyBGDirs[$member]
        set child_ARGS = ($CyclingFCDirs[$member] ${FCFilePrefix} ${bgDir} ${nextDate} ${CYWindowHR})
        set child_DependsOn=fc_mem${member}

        @ member++

        if ( $active == 0 ) continue

        cd ${MAIN_SCRIPT_DIR}
        set WrapperScript=${MAIN_SCRIPT_DIR}/${myWrapper}_OMB.csh
        sed -e 's@WorkDirArg@'${WorkDir}'@' \
            -e 's@JobNameArg@'${omm}'_job@' \
            -e 's@DependTypeArg@'${child_DependsOn}'@' \
            -e 's@wrapDateArg@'$child_ARGS[4]'@' \
            -e 's@wrapStateDirArg@'$child_ARGS[1]'@' \
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
            ${MAIN_SCRIPT_DIR}/${myWrapper}.csh > ${WrapperScript}
        chmod 744 ${WrapperScript}
        ${WrapperScript}

        cd ${WorkDir}
        ${SubmitWrapperJobs}
        set JobScripts=(`cat JobScripts`)
        set JobTypes=(`cat JobTypes`)
        set JobDependencies=(`cat JobDependencies`)
        set i = 1
        while ($i < ${#JobScripts})
          set JobScript = "$JobScripts[$i]"
          if ( $doJobs[$i] == 1 && "$JobScript" != "None" ) then
            set JALL=(`cat ${JOBCONTROL}/$JobDependencies[$i]`)
            set JDEP = "${DEPSTART}"
            foreach J ($JALL)
              if (${J} != "$nulljob" ) set JDEP = ${JDEP}"${DEPSEP}"${J}
            end
            if ($JDEP != "") set JDEP = "${DEPEND}"${JDEP}
            set J = `${SUBMIT} "${JDEP}" $JobScript`
            if ($SUBMIT == sbatch) set J = `echo $J | sed 's@Submitted batch job @@'`
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

#------- ExtendedFC ---------
          if ( ${doExtendedFC} == 0 ) then
            set child_DependsOn=da_job
            rm -rf $ExtendedFCDirs[$member]
            mkdir -p $ExtendedFCDirs[$member]

            set finalExtendedFCDate = `$advanceCYMDH ${cycle_Date} ${ExtendedFCWindowHR}`
            echo "\n${ExtendedFCWindowHR}-hr verification FC from ${cycle_Date} to ${finalExtendedFCDate}"

            cd ${MAIN_SCRIPT_DIR}
            ln -sf ${MAIN_SCRIPT_DIR}/setup.csh $ExtendedFCDirs[$member]/
            set JobScript=$ExtendedFCDirs[$member]/fc_job.csh
            sed -e 's@inDateArg@'${cycle_Date}'@' \
                -e 's@inStateDirArg@'$CyclingDAOutDirs[$member]'@' \
                -e 's@inStatePrefixArg@'${ANFilePrefix}'@' \
                -e 's@fcLengthHRArg@'${ExtendedFCWindowHR}'@' \
                -e 's@fcIntervalHRArg@'${ExtendedFC_DT_HR}'@' \
                -e 's@JobMinutesArg@'${ExtendedFCJobMinutes}'@' \
                -e 's@AccountNumberArg@'${CYAccountNumber}'@' \
                -e 's@QueueNameArg@'${CYQueueName}'@' \
                -e 's@ExpNameArg@'${ExpName}'@' \
                ${MAIN_SCRIPT_DIR}/fc_job.csh > ${JobScript}
            chmod 744 ${JobScript}

            cd $ExtendedFCDirs[$member]

            set JALL=(`cat ${JOBCONTROL}/${child_DependsOn}`)
            set JDEP = "${DEPSTART}"
            foreach J ($JALL)
              if (${J} != "$nulljob" ) then
                set JDEP = ${JDEP}"${DEPSEP}"${J}
              endif
            end
            if ($JDEP != "") set JDEP = "${DEPEND}"${JDEP}
            set J = `${SUBMIT} "${JDEP}" ${JobScript}`
            if ($SUBMIT == sbatch) set J = `echo $J | sed 's@Submitted batch job @@'`
            echo "${J}" > ${JOBCONTROL}/exfc_mem${member}
          endif


#------- verify fc state(s) ---------
          set child_DependsOn=exfc_mem${member}
          set myWrapper = appANDverify

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
              set WrapperScript=${MAIN_SCRIPT_DIR}/${myWrapper}_OMF.csh
              sed -e 's@WorkDirArg@'${WorkDir}'@' \
                  -e 's@JobNameArg@'${omm}'_job@' \
                  -e 's@DependTypeArg@'${child_DependsOn}'@' \
                  -e 's@wrapDateArg@'$child_ARGS[4]'@' \
                  -e 's@wrapStateDirArg@'$child_ARGS[1]'@' \
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
                  ${MAIN_SCRIPT_DIR}/${myWrapper}.csh > ${WrapperScript}
              chmod 744 ${WrapperScript}
              ${WrapperScript}

              cd ${WorkDir}
              set JobScripts=(`cat JobScripts`)
              set JobTypes=(`cat JobTypes`)
              set JobDependencies=(`cat JobDependencies`)
              set i = 1
              while ($i < ${#JobScripts})
                set JobScript = "$JobScripts[$i]"
                if ( $doJobs[$i] == 1 && "$JobScript" != "None" ) then
                  set JALL=(`cat ${JOBCONTROL}/$JobDependencies[$i]`)
                  set JDEP = "${DEPSTART}"
                  foreach J ($JALL)
                    if (${J} != "$nulljob" ) set JDEP = ${JDEP}"${DEPSEP}"${J}
                  end
                  if ($JDEP != "") set JDEP = "${DEPEND}"${JDEP}
                  set J = `${SUBMIT} "${JDEP}" $JobScript`
                  if ($SUBMIT == sbatch) set J = `echo $J | sed 's@Submitted batch job @@'`
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
