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

    echo "=============================================================="
    echo ""
    echo "Initiating cycling experiment for experiment: ${EXPNAME}"
    echo ""
    echo "=============================================================="

#
# 1, Initial and final times of the period:
# =========================================
    setenv FIRSTCYCLE 2018041500 # experiment first cycle date (GFS ANALYSIS)
    setenv S_DATE     2018041500 # experiment start date
    setenv E_DATE     2018051418 # experiment end date

    setenv C_DATE     ${S_DATE}  # current-cycle date (will change)

    set VERIFYBG = 1
    set VERIFYAN = 1

    set ONLYFCVF = 0
    set VERIFYFC = 0

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

        if ( "$DATYPE" =~ *"eda"* ) then
          mkdir ${P_DATE}
          set member = 1
          while ( $member <= ${NMEMBERS} )
            set FCWorkDir = ./${P_DATE}`printf "/mem%03d" $member`
            rm ${FCWorkDir}

            set FCINIT = $GEFSANA6HFC_DIR/${P_DATE}/`print "%02d" $member`
            ln -sf ${FCINIT} ${FCWorkDir}

            @ member++
          end
        else
          ln -sf $GFSANA6HFC_DIR/${P_DATE} .
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
        setenv BGPREFIX ${BG_FILE_PREFIX}
      endif

      echo ""
      echo "Working on cycle: ${C_DATE}"

#------- analysis step ---------
      set DAWorkDir=${DA_CCYCLE_DIR}

      if ( ${ONLYOMM} == 0 && ${ONLYFCVF} == 0 ) then
        echo ""
        echo "analysis at ${C_DATE}"

        mkdir -p ${DAWorkDir}
        cp setup.csh ${DAWorkDir}/

        set VFSCRIPT=${DAWorkDir}/vf_job_${C_DATE}_${EXPNAME}.csh
        sed -e 's@CDATE@'${C_DATE}'@' \
            -e 's@ACCOUNTNUM@'${VFACCOUNTNUM}'@' \
            -e 's@QUEUENAME@'${VFQUEUENAME}'@' \
            -e 's@EXPNAME@'${EXPNAME}'@' \
            vf_job.csh > ${VFSCRIPT}
        chmod 744 ${VFSCRIPT}

        set DASCRIPT=${DAWorkDir}/da_job_${C_DATE}_${EXPNAME}.csh
        sed -e 's@CDATE@'${C_DATE}'@' \
            -e 's@ACCOUNTNUM@'${CYACCOUNTNUM}'@' \
            -e 's@QUEUENAME@'${CYQUEUENAME}'@' \
            -e 's@EXPNAME@'${EXPNAME}'@' \
            da_job.csh > ${DASCRIPT}
        chmod 744 ${DASCRIPT}

        set da_wrapper=${DAWorkDir}/da_wrapper_${C_DATE}_${EXPNAME}.csh
        sed -e 's@CDATE@'${C_DATE}'@' \
            -e 's@WINDOWHR@'${CY_WINDOW_HR}'@' \
            -e 's@FCDIR@'${FCCY_PCYCLE_DIR}'@' \
            -e 's@BGSTATEPREFIX@'${BGPREFIX}'@' \
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
#            -e 's@DIAGTYPE@'${DATYPE}'@' \

        cd ${DAWorkDir}

        ${da_wrapper} >& da_wrapper.log
      endif

#------- verify an step ---------
      set STATEID=${AN_FILE_PREFIX}
      setenv VF_CYCLE_DIR "${VF_WORK_DIR}/${STATEID}/${C_DATE}"
      set VF0h_CYCLE_DIR=${VF_CYCLE_DIR}

      if ( ${VERIFYAN} > 0 && ${ONLYFCVF} == 0 ) then
        set member = 1
        while ( $member <= ${NMEMBERS} )
          cd ${MAIN_SCRIPT_DIR}

          if ( "$DATYPE" =~ *"eda"* ) then
            set ANMemberDir = `printf "/${AN_FILE_PREFIX}/mem%03d" $member`
          else
            set ANMemberDir = ''
          endif

          set anDir=${DAWorkDir}${ANMemberDir}

          set FCBASE = ''
          if ( "$DATYPE" =~ *"eda"* ) then
            set FCBASE = '/'`basename "${anDir}"`
          endif
          set MY_VF_DIR = ${VF_CYCLE_DIR}${FCBASE}

          set OMMSCRIPT=${omm}_wrapper_OMA.csh
          sed -e 's@VFSTATEDATE_in@'${C_DATE}'@' \
              -e 's@WINDOWHR_in@'${CY_WINDOW_HR}'@' \
              -e 's@VFSTATEDIR_in@'${anDir}'@' \
              -e 's@VFFILEPREFIX_in@'${STATEID}'@' \
              -e 's@VFCYCLEDIR_in@'${MY_VF_DIR}'@' \
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
        cd ${MAIN_SCRIPT_DIR}

        set STATEID=${BG_FILE_PREFIX}
        setenv VF_CYCLE_DIR "${VF_WORK_DIR}/${STATEID}/${C_DATE}"

        set BGMemberDir = ''
        if ( "$DATYPE" =~ *"eda"* ) then
          echo "INITIAL OMM NOT ENABLED FOR EDA"
        else
          set bgDir=${DAWorkDir}${BGMemberDir}

          set OMMSCRIPT=${omm}_wrapper_OMB0.csh
          sed -e 's@VFSTATEDATE_in@'${C_DATE}'@' \
              -e 's@WINDOWHR_in@'${CY_WINDOW_HR}'@' \
              -e 's@VFSTATEDIR_in@'${bgDir}'@' \
              -e 's@VFFILEPREFIX_in@'${BGPREFIX}'@' \
              -e 's@VFCYCLEDIR_in@'${VF_CYCLE_DIR}'@' \
              -e 's@VARBCTABLE_in@'${VARBC_TABLE}'@' \
              -e 's@DIAGTYPE_in@omb@' \
              -e 's@BGTYPE_in@1@' \
              -e 's@DEPENDTYPE_in@null@' \
              ${omm}_wrapper.csh > ${OMMSCRIPT}
          chmod 744 ${OMMSCRIPT}
          ./${OMMSCRIPT}
        endif
      endif

#------- cycling forecast step ---------
      set FCWorkDir=${FCCY_CCYCLE_DIR}

      set DEPEND_TYPE=da
      set JDA=`cat ${JOBCONTROL}/last_${DEPEND_TYPE}_job`

      set FCWorkDirs=()
      if ( ${ONLYFCVF} == 0 ) then
        if ( ${ONLYOMM} == 0 ) then
          cd ${MAIN_SCRIPT_DIR}
          rm ${JOBCONTROL}/last_fc_job
          set member = 1
          while ( $member <= ${NMEMBERS} )
            if ( "$DATYPE" =~ *"eda"* ) then
              set FCMemberDir = `printf "/mem%03d" $member`
              set ANMemberDir = /${AN_FILE_PREFIX}${FCMemberDir}

            else
              set FCMemberDir = ''
              set ANMemberDir = ''
            endif

            set WorkDir=${FCWorkDir}${FCMemberDir}
            set ANWorkDir=${DAWorkDir}${ANMemberDir}
            set FCWorkDirs=(${FCWorkDirs} ${WorkDir})
            echo "DEBUG: FC WorkDir = ${WorkDir}"

            rm -rf ${WorkDir}
            mkdir -p ${WorkDir}
            cp setup.csh ${WorkDir}/

            echo ""
            echo "${CY_WINDOW_HR}-hr cycle FC from ${C_DATE} to ${N_DATE}"
            set fc_job=${WorkDir}/fc_job_${C_DATE}_${EXPNAME}.csh
            sed -e 's@CDATE@'${C_DATE}'@' \
                -e 's@JOBMINUTES@'${FCCYJOBMINUTES}'@' \
                -e 's@ACCOUNTNUM@'${CYACCOUNTNUM}'@' \
                -e 's@QUEUENAME@'${CYQUEUENAME}'@' \
                -e 's@EXPNAME@'${EXPNAME}'@' \
                -e 's@FCDIR@'${WorkDir}'@' \
                -e 's@DADIR@'${ANWorkDir}'@' \
                -e 's@ICFILEPREFIX@'${AN_FILE_PREFIX}'@' \
                -e 's@FCLENGTHHR@'${CY_WINDOW_HR}'@' \
                -e 's@OUTDTHR@'${CY_WINDOW_HR}'@' \
                fc_job.csh > ${fc_job}
            chmod 744 ${fc_job}

            cd ${WorkDir}

            if ( ${JDA} == 0 ) then
              set JFC = `qsub -h ${fc_job}`
            else
              set JFC = `qsub -W depend=afterok:${JDA} ${fc_job}`
            endif
            echo "${JFC}" >> ${JOBCONTROL}/last_fc_job

            @ member++
          end
        else
          set JFC=0
        endif

#------- verify bg step ---------
        set STATEID=${BG_FILE_PREFIX}
        setenv VF_CYCLE_DIR "${VF_WORK_DIR}/${STATEID}/${N_DATE}"

        if ( ${VERIFYBG} > 0 ) then
          foreach WorkDir ($FCWorkDirs)
            cd ${MAIN_SCRIPT_DIR}
            set FCBASE = ''
            if ( "$DATYPE" =~ *"eda"* ) then
              set FCBASE = '/'`basename "${WorkDir}"`
            endif
            set MY_VF_DIR = ${VF_CYCLE_DIR}${FCBASE}

            set OMMSCRIPT=${omm}_wrapper_OMB.csh
            sed -e 's@VFSTATEDATE_in@'${N_DATE}'@' \
                -e 's@WINDOWHR_in@'${CY_WINDOW_HR}'@' \
                -e 's@VFSTATEDIR_in@'${WorkDir}'@' \
                -e 's@VFFILEPREFIX_in@'${STATEID}'@' \
                -e 's@VFCYCLEDIR_in@'${MY_VF_DIR}'@' \
                -e 's@VARBCTABLE_in@'${VARBC_TABLE}'@' \
                -e 's@DIAGTYPE_in@omb@' \
                -e 's@BGTYPE_in@1@' \
                -e 's@DEPENDTYPE_in@fc@' \
                ${omm}_wrapper.csh > ${OMMSCRIPT}
            chmod 744 ${OMMSCRIPT}
            ./${OMMSCRIPT}
          end
        endif

        if ( ${JDA} == 0 && ${JFC} != 0 ) then
          qrls $JFC
        endif
      endif

#------- extended forecast step ---------
      if ( ${VERIFYFC} > 0 && ${C_DATE} == ${N_FCVFDATE}) then
        if ( "$DATYPE" =~ *"eda"* ) then
          echo "VERIFYING FORECAST NOT ENABLED FOR EDA"
        else
          set N_FCVFDATE = `$HOME/bin/advance_cymdh ${C_DATE} ${FCVF_INTERVAL_HR}`

          setenv FCVF_CYCLE_DIR "${FCVF_WORK_DIR}/${C_DATE}"
          set WorkDir=${FCVF_CYCLE_DIR}
          set E_VFDATE = `$HOME/bin/advance_cymdh ${C_DATE} ${FCVF_LENGTH_HR}`

          if ( ${ONLYOMM} == 0 ) then

            set DEPEND_TYPE=da
            set JDA=`cat ${JOBCONTROL}/last_${DEPEND_TYPE}_job`

              cd ${MAIN_SCRIPT_DIR}
            rm -rf ${WorkDir}
            mkdir -p ${WorkDir}
            cp setup.csh ${WorkDir}/

            echo ""
            echo "${FCVF_LENGTH_HR}-hr verification FC from ${C_DATE} to ${E_VFDATE}"
            set fcvf_job=${WorkDir}/fcvf_job_${C_DATE}_${EXPNAME}.csh
            sed -e 's@CDATE@'${C_DATE}'@' \
                -e 's@JOBMINUTES@'${FCVFJOBMINUTES}'@' \
                -e 's@ACCOUNTNUM@'${CYACCOUNTNUM}'@' \
                -e 's@QUEUENAME@'${CYQUEUENAME}'@' \
                -e 's@EXPNAME@'${EXPNAME}'@' \
                -e 's@FCDIR@'${WorkDir}'@' \
                -e 's@DADIR@'${DAWorkDir}'@' \
                -e 's@ICFILEPREFIX@'${AN_FILE_PREFIX}'@' \
                -e 's@FCLENGTHHR@'${FCVF_LENGTH_HR}'@' \
                -e 's@OUTDTHR@'${FCVF_DT_HR}'@' \
                fc_job.csh > ${fcvf_job}
            chmod 744 ${fcvf_job}

            cd ${WorkDir}

            if ( ${JDA} == 0 ) then
              set JFCVF = `qsub -h ${fcvf_job}`
            else
              set JFCVF = `qsub -W depend=afterok:${JDA} ${fcvf_job}`
            endif
            echo "${JFCVF}" > ${JOBCONTROL}/last_fcvf_job
          else
            set JFCVF = 0
          endif

#------- verify fc step ---------
          set C_VFDATE = `$HOME/bin/advance_cymdh ${C_DATE} ${FCVF_DT_HR}`
          @ dt = ${FCVF_DT_HR}
          setenv VF_CYCLE_DIR "${OMF_WORK_DIR}/${C_DATE}"
          mkdir -p ${VF_CYCLE_DIR}
          cd ${VF_CYCLE_DIR}

          ## 0 hr fc length
          ln -sf ${VF0h_CYCLE_DIR} ./0hr

          ## all other fc lengths
          while ( ${C_VFDATE} <= ${E_VFDATE} )
            cd ${MAIN_SCRIPT_DIR}
            setenv VF_DIR "${VF_CYCLE_DIR}/${dt}hr"

            set OMMSCRIPT=${omm}_wrapper_OMF_${dt}hr.csh
            sed -e 's@VFSTATEDATE_in@'${C_VFDATE}'@' \
                -e 's@WINDOWHR_in@'${VF_WINDOW_HR}'@' \
                -e 's@VFSTATEDIR_in@'${WorkDir}'@' \
                -e 's@VFFILEPREFIX_in@'${BG_FILE_PREFIX}'@' \
                -e 's@VFCYCLEDIR_in@'${VF_DIR}'@' \
                -e 's@VARBCTABLE_in@'${VARBC_TABLE}'@' \
                -e 's@DIAGTYPE_in@omf@' \
                -e 's@BGTYPE_in@1@' \
                -e 's@DEPENDTYPE_in@fcvf@' \
                ${omm}_wrapper.csh > ${OMMSCRIPT}
            chmod 744 ${OMMSCRIPT}
            ./${OMMSCRIPT}

            set C_VFDATE = `$HOME/bin/advance_cymdh ${C_VFDATE} ${FCVF_DT_HR}`
            setenv C_VFDATE ${C_VFDATE}
            @ dt = $dt + $FCVF_DT_HR
          end

          if ( ${JDA} == 0 && ${JFCVF} != 0 ) then
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
