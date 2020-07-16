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
    echo "0" > ${JOBCONTROL}/last_fcvf_job
    echo "0" > ${JOBCONTROL}/last_null_job

    echo "=============================================================="
    echo ""
    echo "OMF cycling for experiment: ${ExpName}"
    echo ""
    echo "=============================================================="

    setenv cycle_Date ${ExpStartDate}  # initialize current cycle date

    set ONLYOMM = 1

#TODO    ## GFS cold start
#TODO    set IC_STATE=GFSCOLD
#TODO    set IC_DIR=/glade/p/mmm/parc/bjung/panda-c/testdata/v7_x1.40962
#TODO    set IC_STATE_PREFIX=x1.40962.init
#TODO    ENSURE THIS IS A COLD START IN NAMELIST.ATMOSPHERE

#    ## Junmei Ban's baseline analysis (conv_clramsua) - no cloud fraction/radius
#    set IC_STATE=ANA_conv_clramsua_JB
#    set IC_DIR=/glade/scratch/jban/pandac/test35_amsua/FC1
#    set IC_STATE_PREFIX=${RSTFilePrefix}

    ## Yali Wu's baseline analysis (conv_clramsua)
    set IC_STATE=ANA_conv_clramsua_YW
#    set IC_DIR=/glade/scratch/wuyl/test2/pandac/test_120km/DA/noAHI
    set IC_DIR=/glade/scratch/wuyl/test2/pandac/test_120km/FC_cyc/noAHI

    set IC_STATE_PREFIX=${RSTFilePrefix}

    set VARBC_TABLE=${INITIAL_VARBC_TABLE}

#
# 2, CYCLE:
# =========
    while ( ${cycle_Date} <= ${ExpEndDate} )
      setenv IC_CYCLE_DIR "${IC_DIR}/${cycle_Date}"

#------- extended forecast step --------- 
      setenv FC_CYCLE_DIR "${ExtendedFCWorkDir}/${IC_STATE}/${cycle_Date}"
      set fcWorkDir=${FC_CYCLE_DIR}
      set finalExtendedFCDate = `$advanceCYMDH ${cycle_Date} ${ExtendedFCWindowHR}`

      echo ""
      echo "Working on cycle: ${cycle_Date}"

      if ( ${ONLYOMM} == 0 ) then

        rm -rf ${fcWorkDir}
        mkdir -p ${fcWorkDir}

        cd ${MAIN_SCRIPT_DIR}
        ln -sf setup.csh ${fcWorkDir}/

        echo ""
        echo "${ExtendedFCWindowHR}-hr verification FC from ${cycle_Date} to ${finalExtendedFCDate}"
        set fcvf_job=${fcWorkDir}/fcvf_job_${cycle_Date}_${ExpName}.csh
        sed -e 's@icDateArg@'${cycle_Date}'@' \
            -e 's@JobMinutes@'${ExtendedFCJobMinutes}'@' \
            -e 's@AccountNumberArg@'${CYAccountNumber}'@' \
            -e 's@QueueNameArg@'${CYQueueName}'@' \
            -e 's@ExpNameArg@'${ExpName}'@' \
            -e 's@icStateDirArg@'${IC_CYCLE_DIR}'@' \
            -e 's@icStatePrefixArg@'${IC_STATE_PREFIX}'@' \
            -e 's@fcLengthHRArg@'${ExtendedFCWindowHR}'@' \
            -e 's@fcIntervalHRArg@'${ExtendedFC_DT_HR}'@' \
            fc_job.csh > ${fcvf_job}
        chmod 744 ${fcvf_job}

        cd ${fcWorkDir}

        set JExtendedFC = `qsub -h ${fcvf_job}`
        echo "${JExtendedFC}" > ${JOBCONTROL}/last_fcvf_job
      else
        set JExtendedFC = 0
      endif

#------- verify fc step ---------
      setenv VF_CYCLE_DIR "${VerificationWorkDir}/${fcDir}-${IC_STATE}/${cycle_Date}"
      mkdir -p ${VF_CYCLE_DIR}
      cd ${VF_CYCLE_DIR}

      ## 0 hr fc length
      set thisVFDate = ${cycle_Date}
      @ dt = 0
      cd ${MAIN_SCRIPT_DIR}
      set VF_DIR = "${VF_CYCLE_DIR}/${dt}hr"

      set OMMSCRIPT=jobANDverify_OMF_${dt}hr.csh
      sed -e 's@WorkDirArg@'${VF_DIR}'@' \
          -e 's@JobNameArg@'${omm}'_job@' \
          -e 's@wrapDateArg@'${thisVFDate}'@' \
          -e 's@DependTypeArg@fcvf@' \
          -e 's@wrapStateDirsArg@'${fcWorkDir}'@' \
          -e 's@wrapStatePrefixArg@'${IC_STATE_PREFIX}'@' \
          -e 's@wrapStateTypeArg@fc@' \
          -e 's@wrapVARBCTableArg@'${VARBC_TABLE}'@' \
          -e 's@wrapWindowHRArg@'${DAVFWindowHR}'@' \
          -e 's@wrapDATypeArg@'${omm}'@g' \
          -e 's@wrapDAModeArg@'${omm}'@g' \
          -e 's@wrapAccountNumberArg@'${VFAccountNumber}'@' \
          -e 's@wrapQueueNameArg@'${VFQueueName}'@' \
          -e 's@wrapNNODEArg@'${OMMNodes}'@' \
          -e 's@wrapNPEArg@'${OMMPEPerNode}'@g' \
          jobANDverify.csh > ${OMMSCRIPT}
      chmod 744 ${OMMSCRIPT}
      ./${OMMSCRIPT}

      ## all other fc lengths
      set thisVFDate = `$advanceCYMDH ${thisVFDate} ${ExtendedFC_DT_HR}`
      @ dt = $dt + $ExtendedFC_DT_HR

      while ( ${thisVFDate} <= ${finalExtendedFCDate} )
        cd ${MAIN_SCRIPT_DIR}
        set VF_DIR = "${VF_CYCLE_DIR}/${dt}hr"

        set OMMSCRIPT=jobANDverify_OMF_${dt}hr.csh
        sed -e 's@WorkDirArg@'${VF_DIR}'@' \
            -e 's@JobNameArg@'${omm}'_job@' \
            -e 's@DependTypeArg@fcvf@' \
            -e 's@wrapDateArg@'${thisVFDate}'@' \
            -e 's@wrapStateDirsArg@'${fcWorkDir}'@' \
            -e 's@wrapStatePrefixArg@'${FCFilePrefix}'@' \
            -e 's@wrapStateTypeArg@fc@' \
            -e 's@wrapVARBCTableArg@'${VARBC_TABLE}'@' \
            -e 's@wrapWindowHRArg@'${DAVFWindowHR}'@' \
            -e 's@wrapDATypeArg@'${omm}'@g' \
            -e 's@wrapDAModeArg@'${omm}'@g' \
            -e 's@wrapAccountNumberArg@'${VFAccountNumber}'@' \
            -e 's@wrapQueueNameArg@'${VFQueueName}'@' \
            -e 's@wrapNNODEArg@'${OMMNodes}'@' \
            -e 's@wrapNPEArg@'${OMMPEPerNode}'@g' \
            jobANDverify.csh > ${OMMSCRIPT}
        chmod 744 ${OMMSCRIPT}
        ./${OMMSCRIPT}

        set thisVFDate = `$advanceCYMDH ${thisVFDate} ${ExtendedFC_DT_HR}`
        @ dt = $dt + $ExtendedFC_DT_HR
      end

      if ( ${JExtendedFC} != 0 ) then
        qrls $JExtendedFC
      endif

#------- advance date ---------
      set cycle_Date = `$advanceCYMDH ${cycle_Date} ${ExtendedFC_INTERVAL_HR}`
      setenv cycle_Date ${cycle_Date}

    end
    exit 0
