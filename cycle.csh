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
    set DACY = 1
    set VERIFYAN = 0

    set FCCY = 1
    set VERIFYBG = 0

    set FCVF = 0
    set VERIFYFC = 0

    # TODO(JJG): add forceIFExists or skipIFExists
    #            flags for individual
    #            DA/FC/OMM/VF stages
    set ONLYVF = 0

#
# 2, CYCLE:
# =========

    echo "==============================================================\n"
    echo "Cycling workflow for experiment: ${ExpName}\n"
    echo "==============================================================\n"
    setenv cycle_Date ${ExpStartDate}  # initialize current cycle date

    ## determine first FCVF date on or after cycle_Date
    set nextFCVFDate = ${FIRSTCYCLE}
    while ( ${nextFCVFDate} < ${cycle_Date} )
      set nextFCVFDate = `$advanceCYMDH ${nextFCVFDate} ${FCVF_INTERVAL_HR}`
    end

    ## cycling
    while ( ${cycle_Date} <= ${ExpEndDate} )
      set prevDate = `$advanceCYMDH ${cycle_Date} -${CYWindowHR}`
      set nextDate = `$advanceCYMDH ${cycle_Date} ${CYWindowHR}`
      setenv prevDate ${prevDate}
      setenv nextDate ${nextDate}

      ## First cycle "forecast" established offline
      # TODO: make FIRSTCYCLE behavior part of FCCY or seperate application
      #       instead of top-level workflow using zero-length fc_job
      if ( ${cycle_Date} == ${FIRSTCYCLE} ) then
        mkdir -p ${FCCY_WORK_DIR}
        rm -r ${FCCY_WORK_DIR}/${prevDate}
        set member = 1
        while ( $member <= ${nEnsDAMembers} )
          set memDir = `${memberDir} $DAType $member`
          if ( "$DAType" =~ *"eda"* ) then
            mkdir ${FCCY_WORK_DIR}/${prevDate}
            set FCINIT = "$ensembleICFirstCycle"`${memberDir} ens $member "${fixedEnsMemFmt}"`
          else
            set FCINIT = $deterministicICFirstCycle
          endif
          ln -sf ${FCINIT} ${FCCY_WORK_DIR}/${prevDate}${memDir}
          @ member++
        end
        setenv VARBC_TABLE ${INITIAL_VARBC_TABLE}
        setenv bgStatePrefix ${RSTFilePrefix}
      else
        setenv VARBC_TABLE ${DA_WORK_DIR}/${prevDate}/${VARBC_ANA}
        setenv bgStatePrefix ${FCFilePrefix}
      endif

      echo "\nWorking on cycle: ${cycle_Date}"

#------- cycling DA ---------
      set DAWorkDir=${DA_WORK_DIR}/${cycle_Date}

      if ( ${DACY} > 1 ) then
        echo "\nanalysis at ${cycle_Date}"

        set child_DependsOn=ensfc

        mkdir -p ${DAWorkDir}
        cp setup.csh ${DAWorkDir}/

        if ( "$DAType" =~ *"eda"* ) then
          set ChildScript=None
          # TODO(JJG): cycling-da verification not yet enabled for EDA
        else
          set ChildScript=${DAWorkDir}/vf_job_${cycle_Date}_${ExpName}.csh
          sed -e 's@DateArg@'${cycle_Date}'@' \
              -e 's@AccountNumArg@'${VFACCOUNTNUM}'@' \
              -e 's@QueueNameArg@'${VFQUEUENAME}'@' \
              -e 's@ExpNameArg@'${ExpName}'@' \
              vf_job.csh > ${ChildScript}
          chmod 744 ${ChildScript}
        endif

        set JobScript=${DAWorkDir}/da_job_${cycle_Date}_${ExpName}.csh
        sed -e 's@AccountNumArg@'${CYACCOUNTNUM}'@' \
            -e 's@QueueNameArg@'${CYQUEUENAME}'@' \
            -e 's@ExpNameArg@'${ExpName}'@' \
            -e 's@NNODE@'${DACYNodes}'@' \
            -e 's@NPE@'${DACYPEPerNode}'@g' \
            -e 's@DateArg@'${cycle_Date}'@' \
            -e 's@DATypeArg@'${DAType}'@' \
            -e 's@bgStateDirArg@'${FCCY_WORK_DIR}/${prevDate}'@' \
            -e 's@bgStatePrefixArg@'${bgStatePrefix}'@' \
            da_job.csh > ${JobScript}
        chmod 744 ${JobScript}

        set myWrapper = da_wrapper
        set WrapperScript=${DAWorkDir}/${myWrapper}_${cycle_Date}_${ExpName}.csh
        sed -e 's@DateArg@'${cycle_Date}'@' \
            -e 's@WindowHRArg@'${CYWindowHR}'@' \
            -e 's@ObsListArg@DAObsList@' \
            -e 's@VARBCTableArg@'${VARBC_TABLE}'@' \
            -e 's@bgStatePrefixArg@'${bgStatePrefix}'@' \
            -e 's@DATypeArg@'${DAType}'@' \
            -e 's@DAModeArg@da@' \
            -e 's@DAJobScriptArg@'${JobScript}'@' \
            -e 's@DependTypeArg@'${child_DependsOn}'@' \
            -e 's@VFJobScriptArg@'${ChildScript}'@' \
            ${myWrapper}.csh > ${WrapperScript}

        chmod 744 ${WrapperScript}

        cd ${DAWorkDir}

        ${WrapperScript} >& ${myWrapper}.log
      endif

#------- verify analysis state ---------
      if ( ${VERIFYAN} > 0 ) then
        set VFARGS = (${DA_WORK_DIR}/${cycle_Date}/${anDir} ${ANFilePrefix} ${anDir} ${cycle_Date})
        set myWrapper = ${omm}_wrapper
        set child_DependsOn=da

        set member = 1
        while ( $member <= ${nEnsDAMembers} )
          cd ${MAIN_SCRIPT_DIR}
          set memDir = `${memberDir} $DAType $member`
          set StateDir = $VFARGS[1]${memDir}
          set WorkDir = ${VF_WORK_DIR}/$VFARGS[3]${memDir}/$VFARGS[4]

          set WrapperScript=${myWrapper}_OMA.csh
          sed -e 's@DateArg@'$VFARGS[4]'@' \
              -e 's@DAWindowHRArg@'${CYWindowHR}'@' \
              -e 's@StateDirArg@'${StateDir}'@' \
              -e 's@StatePrefixArg@'$VFARGS[2]'@' \
              -e 's@WorkDirArg@'${WorkDir}'@' \
              -e 's@VARBCTableArg@'${VARBC_TABLE}'@' \
              -e 's@DependTypeArg@'${child_DependsOn}'@' \
              ${myWrapper}.csh > ${WrapperScript}
          chmod 744 ${WrapperScript}
          ./${WrapperScript}
          @ member++
        end
      endif

#------- verify FIRSTCYCLE bg state ---------
      if ( ${cycle_Date} == ${FIRSTCYCLE} && ${VERIFYBG} > 0 ) then
        set VFARGS = (${DA_WORK_DIR}/${cycle_Date}/${bgDir} ${bgStatePrefix} ${bgDir} ${cycle_Date})
        set myWrapper = ${omm}_wrapper
        # TODO: currently depends on da to add MPASDiagVars to BG file.
        #       can do that instead with a zero-length fc_job
        set child_DependsOn=da

        set member = 1
        while ( $member <= ${nEnsDAMembers} )
          cd ${MAIN_SCRIPT_DIR}
          set memDir = `${memberDir} $DAType $member`
          set StateDir = $VFARGS[1]${memDir}
          set WorkDir = ${VF_WORK_DIR}/$VFARGS[3]${memDir}/$VFARGS[4]

          set WrapperScript=${myWrapper}_OMB.csh
          sed -e 's@DateArg@'$VFARGS[4]'@' \
              -e 's@DAWindowHRArg@'${CYWindowHR}'@' \
              -e 's@StateDirArg@'${StateDir}'@' \
              -e 's@StatePrefixArg@'$VFARGS[2]'@' \
              -e 's@WorkDirArg@'${WorkDir}'@' \
              -e 's@VARBCTableArg@'${VARBC_TABLE}'@' \
              -e 's@CYOMMTypeArg@omb@' \
              -e 's@DependTypeArg@'${child_DependsOn}'@' \
              ${myWrapper}.csh > ${WrapperScript}
          chmod 744 ${WrapperScript}
          ./${WrapperScript}

          @ member++
        end
      endif

#------- cycling forecast ---------
      if ( ${FCCY} > 0 ) then
        set child_DependsOn=da
        rm ${JOBCONTROL}/last_ensfc_job
        set member = 1
        while ( $member <= ${nEnsDAMembers} )
          cd ${MAIN_SCRIPT_DIR}
          set memDir = `${memberDir} $DAType $member`
          set StateDir = ${DA_WORK_DIR}/${cycle_Date}/${anDir}${memDir}
          set WorkDir = ${FCCY_WORK_DIR}/${cycle_Date}${memDir}

          rm -rf ${WorkDir}
          mkdir -p ${WorkDir}
          cp setup.csh ${WorkDir}/

          echo "\n${CYWindowHR}-hr cycle FC from ${cycle_Date} to ${nextDate} for member $member"
          set JobScript=${WorkDir}/fc_job_${cycle_Date}_${ExpName}.csh
          sed -e 's@icDateArg@'${cycle_Date}'@' \
              -e 's@JobMinutes@'${FCCYJobMinutes}'@' \
              -e 's@AccountNumArg@'${CYACCOUNTNUM}'@' \
              -e 's@QueueNameArg@'${CYQUEUENAME}'@' \
              -e 's@ExpNameArg@'${ExpName}'@' \
              -e 's@icStateDirArg@'${StateDir}'@' \
              -e 's@icStatePrefixArg@'${ANFilePrefix}'@' \
              -e 's@fcLengthHRArg@'${CYWindowHR}'@' \
              -e 's@fcIntervalHRArg@'${CYWindowHR}'@' \
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

          @ member++
        end
      endif

#------- verify forecasted bg state ---------
      if ( ${VERIFYBG} > 0 ) then
        set VFARGS = (${FCCY_WORK_DIR}/${cycle_Date} ${FCFilePrefix} ${bgDir} ${nextDate})
        set myWrapper = ${omm}_wrapper

        set member = 1
        while ( $member <= ${nEnsDAMembers} )
          set child_DependsOn=fc_mem${member}

          cd ${MAIN_SCRIPT_DIR}
          set memDir = `${memberDir} $DAType $member`
          set StateDir = $VFARGS[1]${memDir}
          set WorkDir = ${VF_WORK_DIR}/$VFARGS[3]${memDir}/$VFARGS[4]

          set WrapperScript=${myWrapper}_OMB.csh
          sed -e 's@DateArg@'$VFARGS[4]'@' \
              -e 's@DAWindowHRArg@'${CYWindowHR}'@' \
              -e 's@StateDirArg@'${StateDir}'@' \
              -e 's@StatePrefixArg@'$VFARGS[2]'@' \
              -e 's@WorkDirArg@'${WorkDir}'@' \
              -e 's@VARBCTableArg@'${VARBC_TABLE}'@' \
              -e 's@CYOMMTypeArg@omb@' \
              -e 's@DependTypeArg@'${child_DependsOn}'@' \
              ${myWrapper}.csh > ${WrapperScript}
          chmod 744 ${WrapperScript}
          ./${WrapperScript}

          @ member++
        end
      endif


      if ( ${cycle_Date} == ${nextFCVFDate}) then
        if ( "$DAType" =~ *"eda"* ) then
          echo "WARNING: verifying forecast not enabled for EDA"
        else
          set member = 1
          set memDir = `${memberDir} $DAType $member`

          set FCVFWorkDir=${FCVF_WORK_DIR}/${cycle_Date}${memDir}
          set finalFCVFDate = `$advanceCYMDH ${cycle_Date} ${FCVFWindowHR}`

#------- verification forecast ---------
          if ( ${FCVF} == 0 ) then
            set child_DependsOn=da

            cd ${MAIN_SCRIPT_DIR}
            rm -rf ${FCVFWorkDir}
            mkdir -p ${FCVFWorkDir}
            cp setup.csh ${FCVFWorkDir}/

            set StateDir = ${DA_WORK_DIR}/${cycle_Date}/${anDir}${memDir}

            echo "\n${FCVFWindowHR}-hr verification FC from ${cycle_Date} to ${finalFCVFDate}"
            set JobScript=${FCVFWorkDir}/fcvf_job_${cycle_Date}_${ExpName}.csh
            sed -e 's@icDateArg@'${cycle_Date}'@' \
                -e 's@JobMinutes@'${FCVFJobMinutes}'@' \
                -e 's@AccountNumArg@'${CYACCOUNTNUM}'@' \
                -e 's@QueueNameArg@'${CYQUEUENAME}'@' \
                -e 's@ExpNameArg@'${ExpName}'@' \
                -e 's@icStateDirArg@'${StateDir}'@' \
                -e 's@icStatePrefixArg@'${ANFilePrefix}'@' \
                -e 's@fcLengthHRArg@'${FCVFWindowHR}'@' \
                -e 's@fcIntervalHRArg@'${FCVF_DT_HR}'@' \
                fc_job.csh > ${JobScript}
            chmod 744 ${JobScript}

            cd ${FCVFWorkDir}

            set JALL=(`cat ${JOBCONTROL}/last_${child_DependsOn}_job`)
            set JDEP = ''
            foreach J ($JALL)
              if (${J} != "$nulljob" ) then
                set JDEP = ${JDEP}:${J}
              endif
            end
            set JFCVF = `qsub -W depend=afterok:${JDEP} ${JobScript}`
            echo "${JFCVF}" > ${JOBCONTROL}/last_fcvf_mem${member}_job
          endif

#------- verify fc state(s) ---------
          if ( ${VERIFYFC} == 0 ) then

            set child_DependsOn=fcvf_mem${member}

            set VFARGS = (${FCVFWorkDir} ${FCFilePrefix} ${fcDir} ${cycle_Date})
            set myWrapper = ${omm}_wrapper

            set StateDir = $VFARGS[1]${memDir}
            set dateWorkDir = ${VF_WORK_DIR}/$VFARGS[3]${memDir}/$VFARGS[4]
            mkdir -p ${dateWorkDir}

            cd ${MAIN_SCRIPT_DIR}

            @ dt = 0
            while ( $VFARGS[4] <= ${finalFCVFDate} )
              set WorkDir = $dateWorkDir/${dt}hr
              # TODO(JJG) can these two logical conditions be replaced
              #           with VERIFYAN and VERIFYBG code?
              #           i.e., generic state verification
              if ( $dt == 0 )  then
                ## 0 hour fc length same as analysis (requires previous VERIFYAN)
                rm -r ${WorkDir}
                ln -sf ${VF_WORK_DIR}/${anDir}${memDir}/${cycle_Date} ${WorkDir}
              else if ( ${dt} == ${CYWindowHR} ) then
                ## CYWindowHR fc length same as background (requires previous VERIFYBG)
                rm -r ${WorkDir}
                ln -sf ${VF_WORK_DIR}/${bgDir}${memDir}/${nextDate} ${WorkDir}
              else
                set WrapperScript=${myWrapper}_OMF.csh
                sed -e 's@DateArg@'$VFARGS[4]'@' \
                    -e 's@DAWindowHRArg@'${DAVFWindowHR}'@' \
                    -e 's@StateDirArg@'${StateDir}'@' \
                    -e 's@StatePrefixArg@'$VFARGS[2]'@' \
                    -e 's@WorkDirArg@'${WorkDir}'@' \
                    -e 's@VARBCTableArg@'${VARBC_TABLE}'@' \
                    -e 's@CYOMMTypeArg@omf@' \
                    -e 's@DependTypeArg@'${child_DependsOn}'@' \
                    ${myWrapper}.csh > ${WrapperScript}
                chmod 744 ${WrapperScript}
                ./${WrapperScript}
              endif

              set VFARGS[4] = `$advanceCYMDH $VFARGS[4] ${FCVF_DT_HR}`
              @ dt = $dt + $FCVF_DT_HR
            end
          endif
        endif

        set nextFCVFDate = `$advanceCYMDH ${nextFCVFDate} ${FCVF_INTERVAL_HR}`
      endif

      cd ${MAIN_SCRIPT_DIR}

#------- advance date ---------
      set cycle_Date = `$advanceCYMDH ${cycle_Date} ${CYWindowHR}`
      setenv cycle_Date ${cycle_Date}
    end

    exit 0
