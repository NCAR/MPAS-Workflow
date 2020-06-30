#!/bin/csh -f
#-----------------------------------------------------
# top-level workflow control for MPAS-JEDI experiments
#-----------------------------------------------------
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
