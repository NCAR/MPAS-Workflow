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
    echo "0" > ${JOBCONTROL}/last_omm_job
    echo "0" > ${JOBCONTROL}/last_fcvf_job
    echo "0" > ${JOBCONTROL}/last_null_job

    echo "=============================================================="
    echo ""
    echo "OMF cycling for experiment: ${EXPNAME}"
    echo ""
    echo "=============================================================="
#
# 1, Initial and final times of the period:
# =========================================
    setenv FIRSTCYCLE 2018041500 # experiment first cycle date (GFS ANALYSIS)

    setenv S_DATE     2018041600 # experiment start date
#    setenv E_DATE     2018041512 # experiment end   date
#    setenv E_DATE     2018042200 # experiment end   date
    setenv E_DATE     2018051412 # experiment end   date

    setenv C_DATE     ${S_DATE}  # current-cycle date (will change)

    set ONLYOMM = 1

#TODO    ## GFS cold start
#TODO    set IC_STATE=GFSCOLD
#TODO    set IC_DIR=/glade/p/mmm/parc/bjung/panda-c/testdata/v7_x1.40962
#TODO    set IC_STATE_PREFIX=x1.40962.init
#TODO    ENSURE THIS IS A COLD START IN NAMELIST.ATMOSPHERE

#    ## Junmei Ban's baseline analysis (conv_clramsua) - no cloud fraction/radius
#    set IC_STATE=ANA_conv_clramsua_JB
#    set IC_DIR=/glade/scratch/jban/pandac/test35_amsua/FC1
#    set IC_STATE_PREFIX=${RST_FILE_PREFIX}

    ## Yali Wu's baseline analysis (conv_clramsua)
    set IC_STATE=ANA_conv_clramsua_YW
#    set IC_DIR=/glade/scratch/wuyl/test2/pandac/test_120km/DA/noAHI
    set IC_DIR=/glade/scratch/wuyl/test2/pandac/test_120km/FC_cyc/noAHI

    set IC_STATE_PREFIX=${RST_FILE_PREFIX}

    set VARBC_TABLE=${INITIAL_VARBC_TABLE}

#
# 2, CYCLE:
# =========
    while ( ${C_DATE} <= ${E_DATE} )
      setenv IC_CYCLE_DIR "${IC_DIR}/${C_DATE}"

#------- extended forecast step --------- 
      setenv FC_CYCLE_DIR "${FCVF_WORK_DIR}/${IC_STATE}/${C_DATE}"
      set FCWorkDir=${FC_CYCLE_DIR}
      set E_VFDATE = `$HOME/bin/advance_cymdh ${C_DATE} ${FCVF_LENGTH_HR}`

      echo ""
      echo "Working on cycle: ${C_DATE}"

      if ( ${ONLYOMM} == 0 ) then

        rm -rf ${FCWorkDir}
        mkdir -p ${FCWorkDir}

        cd ${MAIN_SCRIPT_DIR}
        cp setup.csh ${FCWorkDir}/

        echo ""
        echo "${FCVF_LENGTH_HR}-hr verification FC from ${C_DATE} to ${E_VFDATE}"
        set fcvf_job=${FCWorkDir}/fcvf_job_${C_DATE}_${EXPNAME}.csh
        sed -e 's@CDATE@'${C_DATE}'@' \
            -e 's@JOBMINUTES@'${FCVFJOBMINUTES}'@' \
            -e 's@ACCOUNTNUM@'${CYACCOUNTNUM}'@' \
            -e 's@QUEUENAME@'${CYQUEUENAME}'@' \
            -e 's@EXPNAME@'${EXPNAME}'@' \
            -e 's@ICDIR@'${IC_CYCLE_DIR}'@' \
            -e 's@ICSTATEPREFIX@'${IC_STATE_PREFIX}'@' \
            -e 's@FCLENGTHHR@'${FCVF_LENGTH_HR}'@' \
            -e 's@OUTDTHR@'${FCVF_DT_HR}'@' \
            fc_job.csh > ${fcvf_job}
        chmod 744 ${fcvf_job}

        cd ${FCWorkDir}

        set JFCVF = `qsub -h ${fcvf_job}`
        echo "${JFCVF}" > ${JOBCONTROL}/last_fcvf_job
      else
        set JFCVF = 0
      endif

#------- verify fc step ---------
      setenv VF_CYCLE_DIR "${VF_WORK_DIR}/${fcDir}-${IC_STATE}/${C_DATE}"
      mkdir -p ${VF_CYCLE_DIR}
      cd ${VF_CYCLE_DIR}

      ## 0 hr fc length
      set C_VFDATE = ${C_DATE}
      @ dt = 0
      cd ${MAIN_SCRIPT_DIR}
      set VF_DIR = "${VF_CYCLE_DIR}/${dt}hr"

      set OMMSCRIPT=${omm}_wrapper_OMF_${dt}hr.csh
      sed -e 's@VFSTATEDATE_in@'${C_VFDATE}'@' \
          -e 's@WINDOWHR_in@'${VF_WINDOW_HR}'@' \
          -e 's@VFSTATEDIR_in@'${FCWorkDir}'@' \
          -e 's@VFFILEPREFIX_in@'${IC_STATE_PREFIX}'@' \
          -e 's@VFCYCLEDIR_in@'${VF_DIR}'@' \
          -e 's@VARBCTABLE_in@'${VARBC_TABLE}'@' \
          -e 's@DIAGTYPE_in@omf@' \
          -e 's@BGTYPE_in@1@' \
          -e 's@DEPENDTYPE_in@fcvf@' \
          ${omm}_wrapper.csh > ${OMMSCRIPT}
      chmod 744 ${OMMSCRIPT}
      ./${OMMSCRIPT}

      ## all other fc lengths
      set C_VFDATE = `$HOME/bin/advance_cymdh ${C_VFDATE} ${FCVF_DT_HR}`
      @ dt = $dt + $FCVF_DT_HR

      while ( ${C_VFDATE} <= ${E_VFDATE} )
        cd ${MAIN_SCRIPT_DIR}
        set VF_DIR = "${VF_CYCLE_DIR}/${dt}hr"

        set OMMSCRIPT=${omm}_wrapper_OMF_${dt}hr.csh
        sed -e 's@VFSTATEDATE_in@'${C_VFDATE}'@' \
            -e 's@WINDOWHR_in@'${VF_WINDOW_HR}'@' \
            -e 's@VFSTATEDIR_in@'${FCWorkDir}'@' \
            -e 's@VFFILEPREFIX_in@'${FC_FILE_PREFIX}'@' \
            -e 's@VFCYCLEDIR_in@'${VF_DIR}'@' \
            -e 's@VARBCTABLE_in@'${VARBC_TABLE}'@' \
            -e 's@DIAGTYPE_in@omf@' \
            -e 's@BGTYPE_in@1@' \
            -e 's@DEPENDTYPE_in@fcvf@' \
            ${omm}_wrapper.csh > ${OMMSCRIPT}
        chmod 744 ${OMMSCRIPT}
        ./${OMMSCRIPT}

        set C_VFDATE = `$HOME/bin/advance_cymdh ${C_VFDATE} ${FCVF_DT_HR}`
        @ dt = $dt + $FCVF_DT_HR
      end

      if ( ${JFCVF} != 0 ) then
        qrls $JFCVF
      endif

#------- advance date ---------
      set C_DATE = `$HOME/bin/advance_cymdh ${C_DATE} ${FCVF_INTERVAL_HR}`
      setenv C_DATE ${C_DATE}

    end
    exit 0
