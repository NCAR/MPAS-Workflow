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
    echo "0" > ${JOBCONTROL}/last_ensfc_job
    set member = 1
    while ( $member <= ${nEnsDAMembers} )
      echo "0" > ${JOBCONTROL}/last_fc_mem${member}_job
      echo "0" > ${JOBCONTROL}/last_fcvf_mem${member}_job
      @ member++
    end
    echo "0" > ${JOBCONTROL}/last_da_job
    echo "0" > ${JOBCONTROL}/last_omm_job
    echo "0" > ${JOBCONTROL}/last_null_job

    ## workflow component selection
    set VERIFYBG = 0
    set VERIFYAN = 0
    set VERIFYFC = 0

    # TODO(JJG): replace ONLY* flags with forceIFExists
    #            or skipIFExists flags for individual
    #            DA/FC/OMM/VF stages
    set ONLYFCVF = 0
    set ONLYOMM = 0

#
# 2, CYCLE:
# =========

    echo "==============================================================\n"
    echo "Cycling workflow for experiment: ${EXPNAME}\n"
    echo "==============================================================\n"
    setenv C_DATE     ${S_DATE}  # current-cycle date (will change)

    ## determine first FCVF date on or after C_DATE
    set N_FCVFDATE = ${FIRSTCYCLE}
    while ( ${N_FCVFDATE} < ${C_DATE} )
      set N_FCVFDATE = `$advanceCYMDH ${N_FCVFDATE} ${FCVF_INTERVAL_HR}`
    end

    ## cycling
    while ( ${C_DATE} <= ${E_DATE} )
      set P_DATE = `$advanceCYMDH ${C_DATE} -${CY_WINDOW_HR}`
      set N_DATE = `$advanceCYMDH ${C_DATE} ${CY_WINDOW_HR}`
      setenv P_DATE ${P_DATE}
      setenv N_DATE ${N_DATE}

      set FCCY_PCYCLE_DIR = ${FCCY_WORK_DIR}/${P_DATE}
      setenv DA_PCYCLE_DIR "${DA_WORK_DIR}/${P_DATE}"

      ## First cycle "forecast" established offline
      # TODO: make FIRSTCYCLE behavior part of FCCY application
      #       instead of top-level workflow with zero-length fc_job
      if ( ${C_DATE} == ${FIRSTCYCLE} ) then
        mkdir -p ${FCCY_WORK_DIR}
        rm -r ${FCCY_PCYCLE_DIR}
        set member = 1
        while ( $member <= ${nEnsDAMembers} )
          set memDir = `${memberDir} $DATYPE $member`
          if ( "$DATYPE" =~ *"eda"* ) then
            mkdir ${FCCY_PCYCLE_DIR}
            set FCINIT = "$ensembleICFirstCycle"`${memberDir} ens $member "${fixedEnsMemFmt}"`
          else
            set FCINIT = $deterministicICFirstCycle
          endif
          ln -sf ${FCINIT} ${FCCY_PCYCLE_DIR}${memDir}
          @ member++
        end
        setenv VARBC_TABLE ${INITIAL_VARBC_TABLE}
        setenv BGPREFIX ${RST_FILE_PREFIX}
      else
        setenv VARBC_TABLE ${DA_PCYCLE_DIR}/${VARBC_ANA}
        setenv BGPREFIX ${FC_FILE_PREFIX}
      endif

      setenv DA_CCYCLE_DIR "${DA_WORK_DIR}/${C_DATE}"
      setenv FCCY_CCYCLE_DIR "${FCCY_WORK_DIR}/${C_DATE}"

      echo "\nWorking on cycle: ${C_DATE}"

#------- analysis step ---------
      set DAWorkDir=${DA_CCYCLE_DIR}

      if ( ${ONLYOMM} == 0 && ${ONLYFCVF} == 0 ) then
        echo "\nanalysis at ${C_DATE}"

        set thisDependsOn=ensfc

        mkdir -p ${DAWorkDir}
        cp setup.csh ${DAWorkDir}/

        if ( "$DATYPE" =~ *"eda"* ) then
          set ChildScript=None
          # TODO(JJG): cycling-da verification not yet enabled for EDA
        else
          set ChildScript=${DAWorkDir}/vf_job_${C_DATE}_${EXPNAME}.csh
          sed -e 's@CDATE@'${C_DATE}'@' \
              -e 's@ACCOUNTNUM@'${VFACCOUNTNUM}'@' \
              -e 's@QUEUENAME@'${VFQUEUENAME}'@' \
              -e 's@EXPNAME@'${EXPNAME}'@' \
              vf_job.csh > ${ChildScript}
          chmod 744 ${ChildScript}
        endif

        set JobScript=${DAWorkDir}/da_job_${C_DATE}_${EXPNAME}.csh
        sed -e 's@ACCOUNTNUM@'${CYACCOUNTNUM}'@' \
            -e 's@QUEUENAME@'${CYQUEUENAME}'@' \
            -e 's@EXPNAME@'${EXPNAME}'@' \
            -e 's@NNODE@'${DACYNodes}'@' \
            -e 's@NPE@'${DACYPEPerNode}'@g' \
            -e 's@CDATE@'${C_DATE}'@' \
            -e 's@DATYPESUB@'${DATYPE}'@' \
            -e 's@BGDIR@'${FCCY_PCYCLE_DIR}'@' \
            -e 's@BGSTATEPREFIX@'${BGPREFIX}'@' \
            da_job.csh > ${JobScript}
        chmod 744 ${JobScript}

        set myWrapper = da_wrapper
        set WrapperScript=${DAWorkDir}/${myWrapper}_${C_DATE}_${EXPNAME}.csh
        sed -e 's@CDATE@'${C_DATE}'@' \
            -e 's@WINDOWHR@'${CY_WINDOW_HR}'@' \
            -e 's@OBSLIST@DA_OBS_LIST@' \
            -e 's@VARBCTABLE@'${VARBC_TABLE}'@' \
            -e 's@DATYPESUB@'${DATYPE}'@' \
            -e 's@DAMODESUB@da@' \
            -e 's@DIAGTYPE@cycle-da@' \
            -e 's@DAJOBSCRIPT@'${JobScript}'@' \
            -e 's@DEPENDTYPE@'${thisDependsOn}'@' \
            -e 's@VFJOBSCRIPT@'${ChildScript}'@' \
            -e 's@YAMLTOPDIR@'${YAMLTOPDIR}'@' \
            -e 's@RESSPECIFICDIR@'${RESSPECIFICDIR}'@' \
            ${myWrapper}.csh > ${WrapperScript}

        chmod 744 ${WrapperScript}

        cd ${DAWorkDir}

        ${WrapperScript} >& ${myWrapper}.log
      endif

#------- verify an step ---------
      if ( ${VERIFYAN} > 0 && ${ONLYFCVF} == 0 ) then
        set VFARGS = (${DAWorkDir}/${anDir} ${AN_FILE_PREFIX} ${anDir} ${C_DATE})
        set myWrapper = ${omm}_wrapper
        set thisDependsOn=da

        set member = 1
        while ( $member <= ${nEnsDAMembers} )
          cd ${MAIN_SCRIPT_DIR}
          set memDir = `${memberDir} $DATYPE $member`
          set StateDir = $VFARGS[1]${memDir}
          set WorkDir = ${VF_WORK_DIR}/$VFARGS[3]${memDir}/$VFARGS[4]

          set WrapperScript=${myWrapper}_OMA.csh
          sed -e 's@VFSTATEDATE_in@'$VFARGS[4]'@' \
              -e 's@WINDOWHR_in@'${CY_WINDOW_HR}'@' \
              -e 's@VFSTATEDIR_in@'${StateDir}'@' \
              -e 's@VFFILEPREFIX_in@'$VFARGS[2]'@' \
              -e 's@VFCYCLEDIR_in@'${WorkDir}'@' \
              -e 's@VARBCTABLE_in@'${VARBC_TABLE}'@' \
              -e 's@DIAGTYPE_in@oma@' \
              -e 's@DEPENDTYPE_in@'${thisDependsOn}'@' \
              ${myWrapper}.csh > ${WrapperScript}
          chmod 744 ${WrapperScript}
          ./${WrapperScript}
          @ member++
        end
      endif

#------- verify first bg step ---------
      if ( ${C_DATE} == ${FIRSTCYCLE} && ${VERIFYBG} > 0 && ${ONLYFCVF} == 0 ) then
        set VFARGS = (${DAWorkDir}/${bgDir} ${BGPREFIX} ${bgDir} ${C_DATE})
        set myWrapper = ${omm}_wrapper
        # TODO: currently depends on da to add MPASDiagVars to BG file.
        #       can do that instead with a zero-length fc_job
        set thisDependsOn=da

        set member = 1
        while ( $member <= ${nEnsDAMembers} )
          cd ${MAIN_SCRIPT_DIR}
          set memDir = `${memberDir} $DATYPE $member`
          set StateDir = $VFARGS[1]${memDir}
          set WorkDir = ${VF_WORK_DIR}/$VFARGS[3]${memDir}/$VFARGS[4]

          set WrapperScript=${myWrapper}_OMB.csh
          sed -e 's@VFSTATEDATE_in@'$VFARGS[4]'@' \
              -e 's@WINDOWHR_in@'${CY_WINDOW_HR}'@' \
              -e 's@VFSTATEDIR_in@'${StateDir}'@' \
              -e 's@VFFILEPREFIX_in@'$VFARGS[2]'@' \
              -e 's@VFCYCLEDIR_in@'${WorkDir}'@' \
              -e 's@VARBCTABLE_in@'${VARBC_TABLE}'@' \
              -e 's@DIAGTYPE_in@omb@' \
              -e 's@DEPENDTYPE_in@'${thisDependsOn}'@' \
              ${myWrapper}.csh > ${WrapperScript}
          chmod 744 ${WrapperScript}
          ./${WrapperScript}

          @ member++
        end
      endif

#------- cycling forecast step ---------
      if ( ${ONLYFCVF} == 0 ) then
        if ( ${ONLYOMM} == 0 ) then
          set thisDependsOn=da
          rm ${JOBCONTROL}/last_ensfc_job
          set member = 1
          while ( $member <= ${nEnsDAMembers} )
            cd ${MAIN_SCRIPT_DIR}
            set memDir = `${memberDir} $DATYPE $member`
            set StateDir = ${DAWorkDir}/${anDir}${memDir}
            set WorkDir = ${FCCY_CCYCLE_DIR}${memDir}

            rm -rf ${WorkDir}
            mkdir -p ${WorkDir}
            cp setup.csh ${WorkDir}/

            echo "\n${CY_WINDOW_HR}-hr cycle FC from ${C_DATE} to ${N_DATE} for member $member"
            set JobScript=${WorkDir}/fc_job_${C_DATE}_${EXPNAME}.csh
            sed -e 's@CDATE@'${C_DATE}'@' \
                -e 's@JobMinutes@'${FCCYJobMinutes}'@' \
                -e 's@ACCOUNTNUM@'${CYACCOUNTNUM}'@' \
                -e 's@QUEUENAME@'${CYQUEUENAME}'@' \
                -e 's@EXPNAME@'${EXPNAME}'@' \
                -e 's@ICDIR@'${StateDir}'@' \
                -e 's@ICSTATEPREFIX@'${AN_FILE_PREFIX}'@' \
                -e 's@FCLENGTHHR@'${CY_WINDOW_HR}'@' \
                -e 's@OUTDTHR@'${CY_WINDOW_HR}'@' \
                fc_job.csh > ${JobScript}
            chmod 744 ${JobScript}

            cd ${WorkDir}

            set JDEP=`cat ${JOBCONTROL}/last_${thisDependsOn}_job`

            if ( ${JDEP} == 0 ) then
              set JFC = `qsub -h ${JobScript}`
            else
              set JFC = `qsub -W depend=afterok:${JDEP} ${JobScript}`
            endif
            echo "${JFC}" >> ${JOBCONTROL}/last_ensfc_job
            echo "${JFC}" > ${JOBCONTROL}/last_fc_mem${member}_job

            @ member++
          end
        endif

#------- verify bg step ---------
        if ( ${VERIFYBG} > 0 ) then
          set VFARGS = (${FCCY_CCYCLE_DIR} ${FC_FILE_PREFIX} ${bgDir} ${N_DATE})
          set myWrapper = ${omm}_wrapper

          set member = 1
          while ( $member <= ${nEnsDAMembers} )
            set thisDependsOn=fc_mem${member}

            cd ${MAIN_SCRIPT_DIR}
            set memDir = `${memberDir} $DATYPE $member`
            set StateDir = $VFARGS[1]${memDir}
            set WorkDir = ${VF_WORK_DIR}/$VFARGS[3]${memDir}/$VFARGS[4]

            set WrapperScript=${myWrapper}_OMB.csh
            sed -e 's@VFSTATEDATE_in@'$VFARGS[4]'@' \
                -e 's@WINDOWHR_in@'${CY_WINDOW_HR}'@' \
                -e 's@VFSTATEDIR_in@'${StateDir}'@' \
                -e 's@VFFILEPREFIX_in@'$VFARGS[2]'@' \
                -e 's@VFCYCLEDIR_in@'${WorkDir}'@' \
                -e 's@VARBCTABLE_in@'${VARBC_TABLE}'@' \
                -e 's@DIAGTYPE_in@omb@' \
                -e 's@DEPENDTYPE_in@'${thisDependsOn}'@' \
                ${myWrapper}.csh > ${WrapperScript}
            chmod 744 ${WrapperScript}
            ./${WrapperScript}

            set JDEP=`cat ${JOBCONTROL}/last_${thisDependsOn}_job`
            if ( "${JDEP}" != 0 ) qrls $JDEP

            @ member++
          end
        endif

      endif

#------- extended forecast step ---------
      if ( ${VERIFYFC} > 0 && ${C_DATE} == ${N_FCVFDATE}) then
        if ( "$DATYPE" =~ *"eda"* ) then
          echo "WARNING: verifying forecast not enabled for EDA"
        else
          set member = 1
          set memDir = `${memberDir} $DATYPE $member`

          set FCVFWorkDir=${FCVF_WORK_DIR}/${C_DATE}${memDir}
          set E_VFDATE = `$advanceCYMDH ${C_DATE} ${FCVF_LENGTH_HR}`

          if ( ${ONLYOMM} == 0 ) then
            set thisDependsOn=da

            cd ${MAIN_SCRIPT_DIR}
            rm -rf ${FCVFWorkDir}
            mkdir -p ${FCVFWorkDir}
            cp setup.csh ${FCVFWorkDir}/

            set StateDir = ${DAWorkDir}/${anDir}${memDir}

            echo "\n${FCVF_LENGTH_HR}-hr verification FC from ${C_DATE} to ${E_VFDATE}"
            set JobScript=${FCVFWorkDir}/fcvf_job_${C_DATE}_${EXPNAME}.csh
            sed -e 's@CDATE@'${C_DATE}'@' \
                -e 's@JobMinutes@'${FCVFJobMinutes}'@' \
                -e 's@ACCOUNTNUM@'${CYACCOUNTNUM}'@' \
                -e 's@QUEUENAME@'${CYQUEUENAME}'@' \
                -e 's@EXPNAME@'${EXPNAME}'@' \
                -e 's@ICDIR@'${StateDir}'@' \
                -e 's@ICSTATEPREFIX@'${AN_FILE_PREFIX}'@' \
                -e 's@FCLENGTHHR@'${FCVF_LENGTH_HR}'@' \
                -e 's@OUTDTHR@'${FCVF_DT_HR}'@' \
                fc_job.csh > ${JobScript}
            chmod 744 ${JobScript}

            cd ${FCVFWorkDir}

            set JDEP=`cat ${JOBCONTROL}/last_${thisDependsOn}_job`

            if ( ${JDEP} == 0 ) then
              set JFCVF = `qsub -h ${JobScript}`
            else
              set JFCVF = `qsub -W depend=afterok:${JDEP} ${JobScript}`
            endif
            echo "${JFCVF}" > ${JOBCONTROL}/last_fcvf_mem${member}_job
          endif

#------- verify fc step ---------
          set thisDependsOn=fcvf_mem${member}

          set VFARGS = (${FCVFWorkDir} ${FC_FILE_PREFIX} ${fcDir} ${C_DATE})
          set myWrapper = ${omm}_wrapper

          set StateDir = $VFARGS[1]${memDir}
          set dateWorkDir = ${VF_WORK_DIR}/$VFARGS[3]${memDir}/$VFARGS[4]
          mkdir -p ${dateWorkDir}

          cd ${MAIN_SCRIPT_DIR}

          @ dt = 0
          while ( $VFARGS[4] <= ${E_VFDATE} )
            set WorkDir = $dateWorkDir/${dt}hr
            # TODO(JJG) can these two logical conditions be replaced
            #           with VERIFYAN and VERIFYBG code?
            #           i.e., generic state verification
            if ( $dt == 0 )  then
              ## 0 hour fc length same as analysis (requires previous VERIFYAN)
              rm -r ${WorkDir}
              ln -sf ${VF_WORK_DIR}/${anDir}${memDir}/${C_DATE} ${WorkDir}
            else if ( ${dt} == ${CY_WINDOW_HR} ) then
              ## CY_WINDOW_HR fc length same as background (requires previous VERIFYBG)
              rm -r ${WorkDir}
              ln -sf ${VF_WORK_DIR}/${bgDir}${memDir}/${N_DATE} ${WorkDir}
            else
              set WrapperScript=${myWrapper}_OMF.csh
              sed -e 's@VFSTATEDATE_in@'$VFARGS[4]'@' \
                  -e 's@WINDOWHR_in@'${VF_WINDOW_HR}'@' \
                  -e 's@VFSTATEDIR_in@'${StateDir}'@' \
                  -e 's@VFFILEPREFIX_in@'$VFARGS[2]'@' \
                  -e 's@VFCYCLEDIR_in@'${WorkDir}'@' \
                  -e 's@VARBCTABLE_in@'${VARBC_TABLE}'@' \
                  -e 's@DIAGTYPE_in@omf@' \
                  -e 's@DEPENDTYPE_in@'${thisDependsOn}'@' \
                  ${myWrapper}.csh > ${WrapperScript}
              chmod 744 ${WrapperScript}
              ./${WrapperScript}
            endif

            set VFARGS[4] = `$advanceCYMDH $VFARGS[4] ${FCVF_DT_HR}`
            @ dt = $dt + $FCVF_DT_HR
          end

          set JDEP=`cat ${JOBCONTROL}/last_${thisDependsOn}_job`
          if ( "${JDEP}" != 0 ) qrls $JDEP
        endif

        set N_FCVFDATE = `$advanceCYMDH ${N_FCVFDATE} ${FCVF_INTERVAL_HR}`
      endif

      cd ${MAIN_SCRIPT_DIR}

#------- advance date ---------
      set C_DATE = `$advanceCYMDH ${C_DATE} ${CY_WINDOW_HR}`
      setenv C_DATE ${C_DATE}
    end

    exit 0
