#!/bin/csh -f
#
# Environment
#
setenv OMP_NUM_THREADS 1
#setenv OOPS_TRACE 1
#setenv OOPS_DEBUG 1
#
# Settings
# =============================================
setenv CYCLE_PERIOD      6
setenv FC2_FCST_LENGTH   10_00:00:00   # 10day fc
setenv FC2_FCST_INTERVAL 1_00:00:00
setenv UPDATESST         True

setenv diff2exp          True 
setenv controlexp        test35_amsua  #amua60it-2node
#if ($diff2exp == True) then
#   setenv FC1DIAG_WORK_DIR2 /glade/scratch/jban/pandac/conv60it-2node/FC1DIAG
#   setenv FC2DIAG_WORK_DIR2 /glade/scratch/jban/pandac/conv60it-2node/FC2DIAG
#endif

setenv TOP_DIR           TOP_DIRTEMPLATE
setenv BIN_DIR           /glade/u/home/yonggangyu/bin
setenv BUNDLE_BUILD_DIR  ${BUILD_DIR}  # BUILD_DIR is set in cycling_autotest.sh
setenv FIX_INPUT_DIR     /glade/p/mmm/parc/liuz/pandac_common
setenv GFSANA6HFC_DIR    ${FIX_INPUT_DIR}/120km_1stCycle_background
setenv GFSANA_DIR        ${FIX_INPUT_DIR}/120km_GFSANA    # path for gfs analysis and sst files
setenv GRAPHINFO_DIR     ${FIX_INPUT_DIR}/120km_graph

setenv DA_YAML_DIR       ${FIX_INPUT_DIR}/120km_DA_YAML
setenv DA_NML_DIR        ${FIX_INPUT_DIR}/120km_DA_NML
setenv FC_NML_DIR        ${FIX_INPUT_DIR}/120km_FC_NML
setenv CONV_OBS_DIR      /glade/p/mmm/parc/liuz/pandac_common/ioda_obs/conv_obs
setenv RAD_OBS_DIR       /glade/p/mmm/parc/liuz/pandac_common/ioda_obs/bias_corr
setenv CRTM_COEFFS       /glade/p/mmm/parc/liuz/pandac_common/crtm_coeffs
#setenv filesbump         /glade/scratch/bjung/x_bumploc
setenv filesbump         /glade/scratch/bjung/x_bumploc_20210208
#setenv GRAPHICS_DIR      /glade/work/jban/pandac/fix_input/120km_graphics_forpr
#copy from jban,          mod plot_modelspace_ts_2d.py for color legend
setenv GRAPHICS_DIR      /glade/work/yonggangyu/pandac/fix_input/120km_graphics_forpr  
#setenv GRAPHICS_DIR       /glade/scratch/yonggangyu/mpasbundletest/code/mpas-bundle/mpasjedi/graphics
#setenv GRAPHICS_DIR      ${FIX_INPUT_DIR}/graphics_testpr

# set the experiment name to the current directory basename, which must match
# ExperimentName in filestructure.csh in MPAS-Workflow and as controlled in
# cycling_autotest.sh.
setenv ExpName           `basename "$PWD"`

setenv DA_WORK_DIR       ${TOP_DIR}/$ExpName/CyclingDA
setenv DA_DIAG_DIR       ${TOP_DIR}/$ExpName/DAdiag
setenv FC1_WORK_DIR      ${TOP_DIR}/$ExpName/CyclingFC
setenv FC2_WORK_DIR      ${TOP_DIR}/$ExpName/FC2
setenv OMF_WORK_DIR      ${TOP_DIR}/$ExpName/OMF

setenv DADIAG_WORK_DIR   ${TOP_DIR}/$ExpName/DADIAG
setenv FC1DIAG_WORK_DIR  ${TOP_DIR}/$ExpName/FC1DIAG
setenv FC2DIAG_WORK_DIR  ${TOP_DIR}/$ExpName/FC2DIAG
setenv FC3_WORK_DIR      ${TOP_DIR}/$ExpName/FC3  # output history 0hfc

# directory where submit_diag.csh is executed
setenv SCRIPT_DIR        `pwd`
