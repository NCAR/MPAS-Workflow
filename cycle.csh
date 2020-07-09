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
    cp -rpP ${ORIG_SCRIPT_DIR}/* ${MAIN_SCRIPT_DIR}/
    cd ${MAIN_SCRIPT_DIR}
    echo "0" > ${JOBCONTROL}/last_fc_job
    echo "0" > ${JOBCONTROL}/last_da_job
    echo "0" > ${JOBCONTROL}/last_omm_job
    echo "0" > ${JOBCONTROL}/last_fcvf_job
    echo "0" > ${JOBCONTROL}/last_null_job

    clear
    echo "==============================================================\n"
    echo "Cycling workflow for experiment: ${EXPNAME}\n"
    echo "==============================================================\n"

#
# 1, Initial and final times of the period:
# =========================================
    setenv S_DATE     2018041500 # experiment start date
#    setenv E_DATE     2018051418 # experiment end date
    setenv E_DATE     2018041506 # experiment end date

    setenv C_DATE     ${S_DATE}  # current-cycle date (will change)

    set VERIFYBG = 1
    set VERIFYAN = 1

    set ONLYFCVF = 1
    set VERIFYFC = 1

    set ONLYOMM = 0

#
# 2, CYCLE:
# =========
    set N_FCVFDATE = ${C_DATE}
    while ( ${C_DATE} <= ${E_DATE} )
      set P_DATE = `$HOME/bin/advance_cymdh ${C_DATE} -${CY_WINDOW_HR}`
      set N_DATE = `$HOME/bin/advance_cymdh ${C_DATE} ${CY_WINDOW_HR}`
      setenv P_DATE ${P_DATE}
      setenv N_DATE ${N_DATE}

      if ( ${C_DATE} == ${FIRSTCYCLE} ) then
        mkdir -p ${FCCY_WORK_DIR}
        cd ${FCCY_WORK_DIR}

        rm -r ${P_DATE}
        if ( "$DATYPE" =~ *"eda"* ) then
          mkdir ${P_DATE}
          set member = 1
          while ( $member <= ${nGEFSMembers} )
            set FCWorkDir = "./${P_DATE}/"`printf "${oopsEnsMemberFormat}" $member`
            set FCINIT = "$GEFSANA6HFC_DIR/${P_DATE}/"`printf "${gefsEnsMemberFormat}" $member`

            ln -sf ${FCINIT} ${FCWorkDir}

            @ member++
          end
        else
          ln -sf $GFSANA6HFC_FIRSTCYCLE ./${P_DATE}
        endif

        cd ${MAIN_SCRIPT_DIR}
      endif

      setenv DA_CCYCLE_DIR "${DA_WORK_DIR}/${C_DATE}"
      setenv DA_PCYCLE_DIR "${DA_WORK_DIR}/${P_DATE}"
      setenv FCCY_CCYCLE_DIR "${FCCY_WORK_DIR}/${C_DATE}"
      setenv FCCY_PCYCLE_DIR "${FCCY_WORK_DIR}/${P_DATE}"

      if ( ${C_DATE} == ${FIRSTCYCLE} ) then
        setenv VARBC_TABLE ${INITIAL_VARBC_TABLE}
        setenv BGPREFIX ${RST_FILE_PREFIX}
      else
        setenv VARBC_TABLE ${DA_PCYCLE_DIR}/${VARBC_ANA}
        setenv BGPREFIX ${FC_FILE_PREFIX}
      endif

      echo "\nWorking on cycle: ${C_DATE}"

#------- analysis step ---------
      set DAWorkDir=${DA_CCYCLE_DIR}

      if ( ${ONLYOMM} == 0 && ${ONLYFCVF} == 0 ) then
        echo "\nanalysis at ${C_DATE}"

        mkdir -p ${DAWorkDir}
        cp setup.csh ${DAWorkDir}/

        if ( "$DATYPE" =~ *"eda"* ) then
          set VFSCRIPT=None
          echo "WARNING: cycling-da verification not enabled for EDA"
        else
          set VFSCRIPT=${DAWorkDir}/vf_job_${C_DATE}_${EXPNAME}.csh
          sed -e 's@CDATE@'${C_DATE}'@' \
              -e 's@ACCOUNTNUM@'${VFACCOUNTNUM}'@' \
              -e 's@QUEUENAME@'${VFQUEUENAME}'@' \
              -e 's@EXPNAME@'${EXPNAME}'@' \
              vf_job.csh > ${VFSCRIPT}
          chmod 744 ${VFSCRIPT}
        endif

        set DASCRIPT=${DAWorkDir}/da_job_${C_DATE}_${EXPNAME}.csh
        sed -e 's@CDATE@'${C_DATE}'@' \
            -e 's@ACCOUNTNUM@'${CYACCOUNTNUM}'@' \
            -e 's@QUEUENAME@'${CYQUEUENAME}'@' \
            -e 's@EXPNAME@'${EXPNAME}'@' \
            -e 's@NNODE@'${DACYNodes}'@' \
            -e 's@NPE@'${DACYPEPerNode}'@g' \
            -e 's@DATYPESUB@'${DATYPE}'@' \
            -e 's@BGDIR@'${FCCY_PCYCLE_DIR}'@' \
            -e 's@BGSTATEPREFIX@'${BGPREFIX}'@' \
            da_job.csh > ${DASCRIPT}
        chmod 744 ${DASCRIPT}

        set da_wrapper=${DAWorkDir}/da_wrapper_${C_DATE}_${EXPNAME}.csh
        sed -e 's@CDATE@'${C_DATE}'@' \
            -e 's@WINDOWHR@'${CY_WINDOW_HR}'@' \
            -e 's@OBSLIST@DA_OBS_LIST@' \
            -e 's@VARBCTABLE@'${VARBC_TABLE}'@' \
            -e 's@DATYPESUB@'${DATYPE}'@' \
            -e 's@DAMODESUB@da@' \
            -e 's@DIAGTYPE@cycle-da@' \
            -e 's@DAJOBSCRIPT@'${DASCRIPT}'@' \
            -e 's@DEPENDTYPE@fc@' \
            -e 's@VFJOBSCRIPT@'${VFSCRIPT}'@' \
            -e 's@YAMLTOPDIR@'${YAMLTOPDIR}'@' \
            -e 's@RESSPECIFICDIR@'${RESSPECIFICDIR}'@' \
            da_wrapper.csh > ${da_wrapper}

        chmod 744 ${da_wrapper}

        cd ${DAWorkDir}

        ${da_wrapper} >& da_wrapper.log
      endif

#------- verify an step ---------
      if ( ${VERIFYAN} > 0 && ${ONLYFCVF} == 0 ) then
        set VFARGS = (${DAWorkDir}/${anDir} ${AN_FILE_PREFIX} ${anDir}/${C_DATE} ${C_DATE})

        set member = 1
        while ( $member <= ${nEnsDAMembers} )
          cd ${MAIN_SCRIPT_DIR}
          if ( "$DATYPE" =~ *"eda"* ) then
            set memberDir = `printf "/${oopsEnsMemberFormat}" $member`
          else
            set memberDir = ''
          endif
          set StateDir = $VFARGS[1]${memberDir}
          set WorkDir = ${VF_WORK_DIR}/$VFARGS[3]${memberDir}

          set OMMSCRIPT=${omm}_wrapper_OMA.csh
          sed -e 's@VFSTATEDATE_in@'$VFARGS[4]'@' \
              -e 's@WINDOWHR_in@'${CY_WINDOW_HR}'@' \
              -e 's@VFSTATEDIR_in@'${StateDir}'@' \
              -e 's@VFFILEPREFIX_in@'$VFARGS[2]'@' \
              -e 's@VFCYCLEDIR_in@'${WorkDir}'@' \
              -e 's@VARBCTABLE_in@'${VARBC_TABLE}'@' \
              -e 's@DIAGTYPE_in@oma@' \
              -e 's@BGTYPE_in@1@' \
              -e 's@DEPENDTYPE_in@da@' \
              ${omm}_wrapper.csh > ${OMMSCRIPT}
          chmod 744 ${OMMSCRIPT}
          ./${OMMSCRIPT}
          @ member++
        end
      endif

      if ( ${C_DATE} == ${FIRSTCYCLE} && ${VERIFYBG} > 0 && ${ONLYFCVF} == 0 ) then
        set VFARGS = (${DAWorkDir}/${bgDir} ${BGPREFIX} ${bgDir}/${C_DATE} ${C_DATE})

        set member = 1
        while ( $member <= ${nEnsDAMembers} )
          cd ${MAIN_SCRIPT_DIR}
          if ( "$DATYPE" =~ *"eda"* ) then
            set memberDir = `printf "/${oopsEnsMemberFormat}" $member`
          else
            set memberDir = ''
          endif
          set StateDir = $VFARGS[1]${memberDir}
          set WorkDir = ${VF_WORK_DIR}/$VFARGS[3]${memberDir}

          set OMMSCRIPT=${omm}_wrapper_OMB.csh
          sed -e 's@VFSTATEDATE_in@'$VFARGS[4]'@' \
              -e 's@WINDOWHR_in@'${CY_WINDOW_HR}'@' \
              -e 's@VFSTATEDIR_in@'${StateDir}'@' \
              -e 's@VFFILEPREFIX_in@'$VFARGS[2]'@' \
              -e 's@VFCYCLEDIR_in@'${WorkDir}'@' \
              -e 's@VARBCTABLE_in@'${VARBC_TABLE}'@' \
              -e 's@DIAGTYPE_in@omb@' \
              -e 's@BGTYPE_in@1@' \
              -e 's@DEPENDTYPE_in@da@' \
              ${omm}_wrapper.csh > ${OMMSCRIPT}
          chmod 744 ${OMMSCRIPT}
          ./${OMMSCRIPT}

          @ member++
        end
      endif

#------- cycling forecast step ---------
      set thisDependsOn=da

      if ( ${ONLYFCVF} == 0 ) then
        if ( ${ONLYOMM} == 0 ) then
          rm ${JOBCONTROL}/last_fc_job
          set member = 1
          while ( $member <= ${nEnsDAMembers} )
            cd ${MAIN_SCRIPT_DIR}
            if ( "$DATYPE" =~ *"eda"* ) then
              set memberDir = `printf "/${oopsEnsMemberFormat}" $member`
            else
              set memberDir = ''
            endif
            set StateDir = ${DAWorkDir}/${anDir}${memberDir}
            set WorkDir = ${FCCY_CCYCLE_DIR}${memberDir}

            rm -rf ${WorkDir}
            mkdir -p ${WorkDir}
            cp setup.csh ${WorkDir}/

            echo "\n${CY_WINDOW_HR}-hr cycle FC from ${C_DATE} to ${N_DATE} for member $member"
            set fc_job=${WorkDir}/fc_job_${C_DATE}_${EXPNAME}.csh
            sed -e 's@CDATE@'${C_DATE}'@' \
                -e 's@JobMinutes@'${FCCYJobMinutes}'@' \
                -e 's@ACCOUNTNUM@'${CYACCOUNTNUM}'@' \
                -e 's@QUEUENAME@'${CYQUEUENAME}'@' \
                -e 's@EXPNAME@'${EXPNAME}'@' \
                -e 's@ICDIR@'${StateDir}'@' \
                -e 's@ICSTATEPREFIX@'${AN_FILE_PREFIX}'@' \
                -e 's@FCLENGTHHR@'${CY_WINDOW_HR}'@' \
                -e 's@OUTDTHR@'${CY_WINDOW_HR}'@' \
                fc_job.csh > ${fc_job}
            chmod 744 ${fc_job}

            cd ${WorkDir}

            set JDEP=`cat ${JOBCONTROL}/last_${thisDependsOn}_job`

            if ( ${JDEP} == 0 ) then
              set JFC = `qsub -h ${fc_job}`
            else
              set JFC = `qsub -W depend=afterok:${JDEP} ${fc_job}`
            endif
            echo "${JFC}" >> ${JOBCONTROL}/last_fc_job

            @ member++
          end
        else
          set JFC=0
        endif

#------- verify bg step ---------
        if ( ${VERIFYBG} > 0 ) then
          set VFARGS = (${FCCY_CCYCLE_DIR} ${FC_FILE_PREFIX} ${bgDir}/${N_DATE} ${N_DATE})
          set thisDependsOn=da

          set member = 1
          while ( $member <= ${nEnsDAMembers} )
            cd ${MAIN_SCRIPT_DIR}
            if ( "$DATYPE" =~ *"eda"* ) then
              set memberDir = `printf "/${oopsEnsMemberFormat}" $member`
            else
              set memberDir = ''
            endif
            set StateDir = $VFARGS[1]${memberDir}
            set WorkDir = ${VF_WORK_DIR}/$VFARGS[3]${memberDir}

            set OMMSCRIPT=${omm}_wrapper_OMB.csh
            sed -e 's@VFSTATEDATE_in@'$VFARGS[4]'@' \
                -e 's@WINDOWHR_in@'${CY_WINDOW_HR}'@' \
                -e 's@VFSTATEDIR_in@'${StateDir}'@' \
                -e 's@VFFILEPREFIX_in@'$VFARGS[2]'@' \
                -e 's@VFCYCLEDIR_in@'${WorkDir}'@' \
                -e 's@VARBCTABLE_in@'${VARBC_TABLE}'@' \
                -e 's@DIAGTYPE_in@omb@' \
                -e 's@BGTYPE_in@1@' \
                -e 's@DEPENDTYPE_in@fc@' \
                ${omm}_wrapper.csh > ${OMMSCRIPT}
            chmod 744 ${OMMSCRIPT}
            ./${OMMSCRIPT}

            @ member++
          end
        endif

        set JDEP=`cat ${JOBCONTROL}/last_${thisDependsOn}_job`

        if ( ${JDEP} == 0 && ${JFC} != 0 ) then
          qrls $JFC
        endif
      endif

#------- extended forecast step ---------
      if ( ${VERIFYFC} > 0 && ${C_DATE} == ${N_FCVFDATE}) then
        if ( "$DATYPE" =~ *"eda"* ) then
          echo "WARNING: verifying forecast not enabled for EDA"
        else
          set memberDir = ''

          set N_FCVFDATE = `$HOME/bin/advance_cymdh ${C_DATE} ${FCVF_INTERVAL_HR}`

          set FCVFWorkDir=${FCVF_WORK_DIR}/${C_DATE}${memberDir}
          set E_VFDATE = `$HOME/bin/advance_cymdh ${C_DATE} ${FCVF_LENGTH_HR}`

          set thisDependsOn=da

          if ( ${ONLYOMM} == 0 ) then

            cd ${MAIN_SCRIPT_DIR}
            rm -rf ${FCVFWorkDir}
            mkdir -p ${FCVFWorkDir}
            cp setup.csh ${FCVFWorkDir}/

            set StateDir = ${DAWorkDir}/${anDir}${memberDir}

            echo "\n${FCVF_LENGTH_HR}-hr verification FC from ${C_DATE} to ${E_VFDATE}"
            set fcvf_job=${FCVFWorkDir}/fcvf_job_${C_DATE}_${EXPNAME}.csh
            sed -e 's@CDATE@'${C_DATE}'@' \
                -e 's@JobMinutes@'${FCVFJobMinutes}'@' \
                -e 's@ACCOUNTNUM@'${CYACCOUNTNUM}'@' \
                -e 's@QUEUENAME@'${CYQUEUENAME}'@' \
                -e 's@EXPNAME@'${EXPNAME}'@' \
                -e 's@ICDIR@'${StateDir}'@' \
                -e 's@ICSTATEPREFIX@'${AN_FILE_PREFIX}'@' \
                -e 's@FCLENGTHHR@'${FCVF_LENGTH_HR}'@' \
                -e 's@OUTDTHR@'${FCVF_DT_HR}'@' \
                fc_job.csh > ${fcvf_job}
            chmod 744 ${fcvf_job}

            cd ${FCVFWorkDir}

            set JDEP=`cat ${JOBCONTROL}/last_${thisDependsOn}_job`

            if ( ${JDEP} == 0 ) then
              set JFCVF = `qsub -h ${fcvf_job}`
            else
              set JFCVF = `qsub -W depend=afterok:${JDEP} ${fcvf_job}`
            endif
            echo "${JFCVF}" > ${JOBCONTROL}/last_fcvf_job
          else
            set JFCVF = 0
          endif

#------- verify fc step ---------
          set thisDependsOn=da

          setenv VF_CYCLE_DIR ${VF_WORK_DIR}/${fcDir}/${C_DATE}
          mkdir -p ${VF_CYCLE_DIR}
          cd ${VF_CYCLE_DIR}

          ## 0 hour fc length
          ln -sf ${VF_WORK_DIR}/${anDir}/${C_DATE} ./0hr

          ## all other fc lengths
          set C_VFDATE = `$HOME/bin/advance_cymdh ${C_DATE} ${FCVF_DT_HR}`
          @ dt = ${FCVF_DT_HR}
          while ( ${C_VFDATE} <= ${E_VFDATE} )
            if ( ${C_DATE} > ${FIRSTCYCLE} && ${dt} == ${CY_WINDOW_HR}) then
              ## CY_WINDOW_HR fc length
              cd ${VF_CYCLE_DIR}
              ln -sf ${VF_WORK_DIR}/${bgDir}/${P_DATE} ./${CY_WINDOW_HR}hr
            else
              cd ${MAIN_SCRIPT_DIR}
              set VFARGS = (${FCVFWorkDir} ${FC_FILE_PREFIX} ${fcDir}/${C_DATE}/${dt}hr ${C_VFDATE})

              set StateDir = $VFARGS[1]${memberDir}
              set WorkDir = ${VF_WORK_DIR}/$VFARGS[3]${memberDir}

              set OMMSCRIPT=${omm}_wrapper_OMF.csh
              sed -e 's@VFSTATEDATE_in@'$VFARGS[4]'@' \
                  -e 's@WINDOWHR_in@'${VF_WINDOW_HR}'@' \
                  -e 's@VFSTATEDIR_in@'${StateDir}'@' \
                  -e 's@VFFILEPREFIX_in@'$VFARGS[2]'@' \
                  -e 's@VFCYCLEDIR_in@'${WorkDir}'@' \
                  -e 's@VARBCTABLE_in@'${VARBC_TABLE}'@' \
                  -e 's@DIAGTYPE_in@omf@' \
                  -e 's@BGTYPE_in@1@' \
                  -e 's@DEPENDTYPE_in@fcvf@' \
                  ${omm}_wrapper.csh > ${OMMSCRIPT}
              chmod 744 ${OMMSCRIPT}
              ./${OMMSCRIPT}
            endif

            set C_VFDATE = `$HOME/bin/advance_cymdh ${C_VFDATE} ${FCVF_DT_HR}`
            setenv C_VFDATE ${C_VFDATE}
            @ dt = $dt + $FCVF_DT_HR
          end

          set JDEP=`cat ${JOBCONTROL}/last_${thisDependsOn}_job`

          if ( ${JDEP} == 0 && ${JFCVF} != 0 ) then
            qrls $JFCVF
          endif
        endif
      endif

      cd ${MAIN_SCRIPT_DIR}

#------- advance date ---------
      set C_DATE = `$HOME/bin/advance_cymdh ${C_DATE} ${CY_WINDOW_HR}`
      setenv C_DATE ${C_DATE}
    end

    exit 0
