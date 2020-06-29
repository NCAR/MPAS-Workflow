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
    echo "0" > ${JOBCONTROL}/last_null_job

    echo "=============================================================="
    echo ""
    echo "OMM cycling for experiment: ${EXPNAME}"
    echo ""
    echo "=============================================================="
#
# 1, Initial and final times of the period:
# =========================================
    setenv FIRSTCYCLE 2018041500 # experiment first cycle date (GFS ANALYSIS)

    setenv S_DATE     2018041500 # experiment start date
    setenv E_DATE     2018041500 # experiment end   date
#    setenv E_DATE     2018042200 # experiment end   date
#    setenv E_DATE     2018051412 # experiment end   date

    setenv C_DATE     ${S_DATE}  # current-cycle date (will change)

#    ## 6-hr FC from GFS (GFS cold start)
#    set BGFROMCYCLEDIR=0
#    set OMM_STATE=6hr-MPAS_GFSCOLD
#    set OMF_DIR=/glade/scratch/wuyl/test2/pandac/test_120km/init_FC
#    set FC_FILE_PREFIX=${RST_FILE_PREFIX}

#    ## 6-hr FC from Junmei Ban's baseline analysis (conv_clramsua)
#    set BGFROMCYCLEDIR=0
#    set OMM_STATE=6hr-MPAS_conv_clramsua_JB
#    # set OMF_DIR=${FIXED_INPUT}/${MPAS_RES}/${MPAS_RES}_GFSANA6HFC
#    set OMF_DIR=/glade/scratch/wuyl/test2/pandac/test_120km/ben_FC
#    set FC_FILE_PREFIX=${RST_FILE_PREFIX}

    ## 6-hr FC from Yali Wu's baseline analysis (conv_clramsua)
    set BGFROMCYCLEDIR=1
    set OMM_STATE=6hr-MPAS_conv_clramsua_YW
    set OMF_DIR=/glade/scratch/wuyl/test2/pandac/test_120km/DA/noAHI
    set FC_FILE_PREFIX=${RST_FILE_PREFIX}

    set STATE_DIR = "${FCVF_WORK_DIR}/${OMM_STATE}"
    mkdir -p ${STATE_DIR}

#
# 2, CYCLE:
# =========
    while ( ${C_DATE} <= ${E_DATE} )
      set P_DATE = `$HOME/bin/advance_cymdh ${C_DATE} -${CY_WINDOW_HR}`
      setenv P_DATE ${P_DATE}

      echo ""
      echo "Working on cycle: ${C_DATE}"

      cd ${STATE_DIR}

      rm ${P_DATE}
      if ( $BGFROMCYCLEDIR ) then
        #if from analysis directories
        ln -sf ${OMF_DIR}/${C_DATE} ./${P_DATE}
      else
        #if from forecast directories
        ln -sf ${OMF_DIR}/${P_DATE} .
      endif

      setenv VF_CYCLE_DIR "${OMF_WORK_DIR}-${OMM_STATE}/${C_DATE}"
      set WORKDIR=${VF_CYCLE_DIR}

      setenv VF_PCYCLE_DIR "${OMF_WORK_DIR}-${OMM_STATE}/${P_DATE}"
      if ( ${C_DATE} == ${FIRSTCYCLE} ) then
         setenv VARBC_TABLE ${INITIAL_VARBC_TABLE}
      else
         setenv VARBC_TABLE ${VF_PCYCLE_DIR}/${VARBC_ANA}
      endif
      setenv STATE_PCYCLE_DIR "${STATE_DIR}/${P_DATE}"

#------- perform omm calculation ---------
      cd ${MAIN_SCRIPT_DIR}

      set OMMSCRIPT=omm_wrapper_TEMP.csh
      sed -e 's@VFSTATEDATE_in@'${C_DATE}'@' \
          -e 's@WINDOWHR_in@'${CY_WINDOW_HR}'@' \
          -e 's@VFSTATEDIR_in@'${STATE_PCYCLE_DIR}'@' \
          -e 's@VFFILEPREFIX_in@'${FC_FILE_PREFIX}'@' \
          -e 's@VFCYCLEDIR_in@'${WORKDIR}'@' \
          -e 's@VARBCTABLE_in@'${VARBC_TABLE}'@' \
          -e 's@DIAGTYPE_in@omb-'${OMM_STATE}'@' \
          -e 's@BGTYPE_in@'${BGFROMCYCLEDIR}'@' \
          -e 's@DEPENDTYPE_in@null@' \
          omm_wrapper.csh > ${OMMSCRIPT}
      chmod 744 ${OMMSCRIPT}
      ./${OMMSCRIPT}

#------- advance date ---------

      set C_DATE = `$HOME/bin/advance_cymdh ${C_DATE} ${CY_WINDOW_HR}`
      setenv C_DATE ${C_DATE}

    end
    exit 0
