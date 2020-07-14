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
    echo "0" > ${JOBCONTROL}/last_omm_job
    echo "0" > ${JOBCONTROL}/last_null_job

    echo "=============================================================="
    echo ""
    echo "OMM cycling for experiment: ${ExpName}"
    echo ""
    echo "=============================================================="

    setenv cycle_Date ${ExpStartDate}  # initialize current cycle date

#    ## 6-hr FC from GFS (GFS cold start)
#    set BGFROMCYCLEDIR=0
#    set OMM_STATE=6hr-MPAS_GFSCOLD
#    set OMF_DIR=/glade/scratch/wuyl/test2/pandac/test_120km/init_FC
#    set FCFilePrefix=${RSTFilePrefix}

#    ## 6-hr FC from Junmei Ban's baseline analysis (conv_clramsua)
#    set BGFROMCYCLEDIR=0
#    set OMM_STATE=6hr-MPAS_conv_clramsua_JB
#    # set OMF_DIR=${FIXED_INPUT}/${MPAS_RES}/${MPAS_RES}_GFSANA6HFC
#    set OMF_DIR=/glade/scratch/wuyl/test2/pandac/test_120km/ben_FC
#    set FCFilePrefix=${RSTFilePrefix}

    ## 6-hr FC from Yali Wu's baseline analysis (conv_clramsua)
    set BGFROMCYCLEDIR=1
    set OMM_STATE=6hr-MPAS_conv_clramsua_YW
    set OMF_DIR=/glade/scratch/wuyl/test2/pandac/test_120km/DA/noAHI
    set FCFilePrefix=${RSTFilePrefix}

    set STATE_DIR = "${FCVF_WORK_DIR}/${OMM_STATE}"
    mkdir -p ${STATE_DIR}

#
# 2, CYCLE:
# =========
    while ( ${cycle_Date} <= ${ExpEndDate} )
      set P_DATE = `$advanceCYMDH ${cycle_Date} -${CYWindowHR}`
      setenv P_DATE ${P_DATE}

      echo ""
      echo "Working on cycle: ${cycle_Date}"

      cd ${STATE_DIR}

      rm ${P_DATE}
      if ( $BGFROMCYCLEDIR ) then
        #if from analysis directories
        ln -sf ${OMF_DIR}/${cycle_Date} ./${P_DATE}
      else
        #if from forecast directories
        ln -sf ${OMF_DIR}/${P_DATE} .
      endif

      setenv VF_CYCLE_DIR "${VF_WORK_DIR}/${fcDir}-${OMM_STATE}/${cycle_Date}"
      set WORKDIR=${VF_CYCLE_DIR}

      setenv VF_PCYCLE_DIR "${VF_WORK_DIR}/${fcDir}-${OMM_STATE}/${P_DATE}"
      if ( ${cycle_Date} == ${FIRSTCYCLE} ) then
         setenv VARBC_TABLE ${INITIAL_VARBC_TABLE}
      else
         setenv VARBC_TABLE ${VF_PCYCLE_DIR}/${VARBC_ANA}
      endif
      setenv STATE_PCYCLE_DIR "${STATE_DIR}/${P_DATE}"

#------- perform omm calculation ---------
      cd ${MAIN_SCRIPT_DIR}

      set OMMSCRIPT=omm_wrapper_TEMP.csh
      sed -e 's@DateArg@'${cycle_Date}'@' \
          -e 's@DAWindowHRArg@'${CYWindowHR}'@' \
          -e 's@StateDirArg@'${STATE_PCYCLE_DIR}'@' \
          -e 's@StatePrefixArg@'${FCFilePrefix}'@' \
          -e 's@WorkDirArg@'${WORKDIR}'@' \
          -e 's@VARBCTableArg@'${VARBC_TABLE}'@' \
          -e 's@CYOMMTypeArg@omb-'${OMM_STATE}'@' \
          -e 's@DependTypeArg@null@' \
          omm_wrapper.csh > ${OMMSCRIPT}
      chmod 744 ${OMMSCRIPT}
      ./${OMMSCRIPT}

#------- advance date ---------

      set cycle_Date = `$advanceCYMDH ${cycle_Date} ${CYWindowHR}`
      setenv cycle_Date ${cycle_Date}

    end
    exit 0
