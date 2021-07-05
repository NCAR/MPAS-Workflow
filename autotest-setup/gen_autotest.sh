#!/bin/bash
#
#   gen_autotest.sh should be run above the checked-out MPAS-Workflow
#   swap
#
#-- 6 d run
initialCycleDate=2018041500
finalCycleDate=2018042100
end_init=2018042018         # Should be one less cycle than DA/FC
#
#   debug options
#--
#
if_ckbuild=0        # 1(def) /0 : check   / No  [build]
if_rundafc=1        # 1(def) /0 : run     / No 
if_pp=1             # 1(def) /0 : pp plot / No
#
#   fixed by now
#--
gridres=OIE120km    # grid resolution
DAType=3denvar      #
tmax=200            # max min to wait for DA+FC completion
tppmax=60           # 
#
name_jedi_dir="mpasbundletest"
[[ $# -ge 1 ]] && echo $1 && name_jedi_dir=$1            # change option
rundir=/glade/scratch/${USER}/${name_jedi_dir}/cycling   # YGYU convention br=build_run
BUILD_DIR=/glade/scratch/${USER}/${name_jedi_dir}/build  # EXE from jedi
startdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"  # should be above MPAS_FLOW


#  This wrapper v.s.  mpas-jedi-autotest/cycling_autotest.sh
#  1. this wrapper allows to decouple check build, runDAFC, and plot
#  2. this wrapper can automatically detect finish-point for DAFC and plots, avoiding sleep 90m.
#  3. it removes logic errors in post-processing plot section
#  4. it corrects an error in handling setup.scr, 
#       sed  -e "s#\${BUILD_DIR}#$BUILD_DIR#" setup.scr;  not exporting $BUILD_DIR VAR!
#  5. encountered and solved the python error in basic_plot_functions.py
#       norm = matplotlib.colors.TwoSlopeNorm(vmin=valuemin, vcenter=0, vmax=valuemax)
#       raise ValueError('vmin, vcenter, and vmax must be in '
#       ValueError: vmin, vcenter, and vmax must be in ascending order
#     error when plotting 2D graphics for current-previous, which can be zero.
#  
#
#  usage: 
#--
#  if_runda=0 : then we can manually link current and previous dir for comparison
#  if_pp =0   : exit without plot
#
#  guideline  :
#  expdir_stamp = topexpdir/basename + ymd_hms
#  expdir_curr  = topexpdir/         + _current
#  expdir_prev  = topexpdir/         + _previous
#  curr_name    = basename +  _current
#  bsname       = basename                       ! name wo time stamp
#
#------------------------------------------------------------#
# S1. set dir name
#------------------------------------------------------------#
#  startdir= start dir above the checked-out MPAS_workflow, at crontab.txt Lev
#
email=${USER}@ucar.edu
WKFL_DIR=${startdir}/MPAS-Workflow
WKFL_DRIVER=${WKFL_DIR}/drive.csh
WKFL_BUILDS_CFG=${WKFL_DIR}/config/builds.csh
WKFL_FLSTRUCT_CFG=${WKFL_DIR}/config/filestructure.csh
WKFL_EXP_CFG=${WKFL_DIR}/config/experiment.csh
WKFL_BENCHMARK_CFG=${WKFL_DIR}/config/benchmark.csh
echo "WKFL_DIR,WKFL_DRIVER,WKFL_BUILDS_CFG,WKFL_FLSTRUCT_CFG,WKFL_BENCHMARK_CFG"
echo "$WKFL_DIR,$WKFL_DRIVER,$WKFL_BUILDS_CFG,$WKFL_FLSTRUCT_CFG,$WKFL_BENCHMARK_CFG"

# Construct the ExpName
bsname=${USER}_${DAType}_${gridres}
ExpSuffix=_$(date '+%Y-%m-%d_%H.%M.%S')
curr_name=${bsname}_current                      # THIS_TEST_NAME
prev_name=${bsname}_previous                     # PREVIOUS_TEST_NAME
expdir_stamp=${rundir}/${bsname}${ExpSuffix}     # absoluteExpDir
expdir_curr=${rundir}/${bsname}_current          # thisexpdir  why export?
expdir_prev=${rundir}/${bsname}_previous         # previousexpdir  export?
expdir_bench=$expdir_prev                        # BenchmarkExpDir
#
# pp
locdir="${startdir}/${curr_name}"
export PATH=$PATH:/opt/pbs/bin                   # for qsub 
export THIS_TEST_NAME=$expdir_curr               # from old script
export PREVIOUS_TEST_NAME=$expdir_prev           #      old script 
#
PLOT_TEMPLATE_DIR=MPAS-Workflow/autotest-setup/Weekly-Diag-Template
ARCHIVE_TOP_DIR=cycling-autotest-analyses
echo "rundir,bsname,ExpSuffix,curr_name,expdir_stamp,expdir_curr,expdir_prev,expdir_bench"
echo "$rundir,$bsname,$ExpSuffix,$curr_name,$expdir_stamp,$expdir_curr,$expdir_prev,$expdir_bench"
echo "nail 1: ck dir setup"


#------------------------------------------------------------#
# S2. sed workflow config/*.csh
#------------------------------------------------------------#
cd ${startdir}
# Modify the workflow
yy=`echo ${initialCycleDate} | cut -c 1-4`
mm=`echo ${initialCycleDate} | cut -c 5-6`
dd=`echo ${initialCycleDate} | cut -c 7-8`
hh=`echo ${initialCycleDate} | cut -c 9-10`
initialCyclePoint=${yy}${mm}${dd}T${hh}
sed -i 's#^set\ initialCyclePoint.*#set\ initialCyclePoint\ =\ '${initialCyclePoint}'#' \
  ${WKFL_DRIVER}
#
yy=`echo ${finalCycleDate} | cut -c 1-4`
mm=`echo ${finalCycleDate} | cut -c 5-6`
dd=`echo ${finalCycleDate} | cut -c 7-8`
hh=`echo ${finalCycleDate} | cut -c 9-10`
finalCyclePoint=${yy}${mm}${dd}T${hh}
sed -i "s#^set\ finalCyclePoint.*#set\ finalCyclePoint\ =\ ${finalCyclePoint}#" \
       ${WKFL_DRIVER}
#
sed -i -e "s#^set\ CompareDA2Benchmark.*#set\ CompareDA2Benchmark\ =\ True#" \
       -e "s#^set\ CompareBG2Benchmark.*#set\ CompareBG2Benchmark\ =\ True#" \
       ${WKFL_DRIVER}
sed -i -e "s#^setenv\ VariationalBuildDir.*#setenv\ VariationalBuildDir\ ${BUILD_DIR}/bin#" \
       -e "s#^setenv\ HofXBuildDir.*#setenv\ HofXBuildDir\ ${BUILD_DIR}/bin#" \
       -e "s#^setenv\ RTPPBuildDir.*#setenv\ RTPPBuildDir\ ${BUILD_DIR}/bin#" \
       -e "s#^setenv\ ForecastTopBuildDir.*#setenv\ ForecastTopBuildDir\ ${BUILD_DIR}#" \
       ${WKFL_BUILDS_CFG}
sed -i "s#^set\ TopExpDir.*#set\ TopExpDir\ =\ ${rundir}#" \
       ${WKFL_FLSTRUCT_CFG}
sed -i -e "s#^setenv\ MPASGridDescriptor.*#setenv\ MPASGridDescriptor\ ${gridres}#" \
       -e "s#^setenv\ DAType.*#setenv\ DAType\ ${DAType}#" \
       -e "s#^set\ ExpSuffix\ =.*#set\ ExpSuffix\ =\ ${ExpSuffix}#" \
       ${WKFL_EXP_CFG}
sed -i "s#^set\ BenchmarkExpDir\ =.*#set\ BenchmarkExpDir\ =\ ${expdir_bench}#" \
       ${WKFL_BENCHMARK_CFG}
#
#
#-- Configure the HPC account
HPCAccount=NMMM0015
HPCQueue=regular
WKFL_JOB_CFG=${WKFL_DIR}/config/job.csh
sed -i -e "s#^setenv\ StandardAccountNumber.*#setenv\ StandardAccountNumber\ ${HPCAccount}#" \
       -e "s#^setenv\ CYQueueName.*#setenv\ CYQueueName\ ${HPCQueue}#" \
       ${WKFL_JOB_CFG}
echo "nail 2: WKFL config/*.csh modification"


#------------------------------------------------------------#
# S3.1 check build ctests and launch "cylc"  DA+FC cycling
#------------------------------------------------------------#
# ctest and build results
if [ $if_ckbuild == 1 ]; then
if [[ -f "${BUILD_DIR}/bin/mpasjedi_variational.x" ]]; then
   # check existence of LastTestsFailed.log
   if [[ -f ${BUILD_DIR}/mpasjedi/Testing/Temporary/LastTestsFailed.log ]]; then
      echo '> 1 ctest failed in build; quit cycling test'
      exit 1
   fi
else
   echo 'mpas-bundle [within ${name_jedi_dir}] failed to build; quit cycling test'
   exit 2
fi
fi
#
## Change to workflow directory; initiate drive.csh
#
cd ${WKFL_DIR}
source env-setup/cheyenne.sh
#
if [ $if_rundafc == 1 ]; then
#
#  push  current -> previous;  stamp -> current
#
  mkdir -p ${expdir_stamp}
  unlink   ${expdir_prev}
  mv       ${expdir_curr}  ${expdir_prev}      # move the curr link to previous
  ln -sfv  ${expdir_stamp} ${expdir_curr}      # create   curr link
  ./drive.csh
else
  echo "if_rundafc -ne 1; ./drive.csh not executed"
fi
if [ $if_pp == 0 ]; then
  exit -1
fi
echo "nail 3: if_ckbuild && if_rundafc"



#------------------------------------------------------------#
# S3.2 check completion for "cylc"  DA+FC cycling
#------------------------------------------------------------#
#
FA="${expdir_curr}/Verification/bg/${finalCycleDate}/Compare2Benchmark/model/BENCHMARK_COMPARE_COMPLETE"
FB="${expdir_curr}/verifymodel_differences_found.txt"
FC="${expdir_curr}/verifyobs_differences_found.txt"
#
#
echo "FA, FB, FC"
echo "$FA, $FB, $FC"
ls $FA; ls $FB; ls $FC
#
#
a=0
until [[ -f $FA ]] && [[ -f $FB || -f $FC ]]; do
  echo "a = $a  wt for DA+FC completion"
  sleep 1m
  a=$(( a+1 ))
  if [ $a -ge $tmax ]; then
    echo "exceeds amax = $tmax; break until condition "
    break
  fi
done
if [ $a -ge $tmax ]; then
  echo "DA+FC cycle failed; autotest stops"
  body="No cycling differences found from previous week."
else
  body="Cycling differences found from last week. See $FB and $FC"
  echo "DA+FC success"
fi
echo "nail 3.2: after completion of DA+FC"


#------------------------------------------------------------#
# S4. sed post-processing python for EXPmGFS
#------------------------------------------------------------#
## plotting scripts, purge dir with curr_name, copy fresh scripts
#
echo "remove locdir= $locdir"
rm -rf $locdir     # risky but have to
mkdir  $locdir
cp     ${startdir}/${PLOT_TEMPLATE_DIR}/* ${locdir}/.
# sed substitution for auto-test settings
sed -i -e "s#TOP_DIRTEMPLATE#${rundir}#" \
       -e "s#\${BUILD_DIR}#$BUILD_DIR#" \
       ${locdir}/setup.csh
sed -i -e "s#start_initTEMPLATE#${initialCycleDate}#" \
       -e "s#end_initTEMPLATE#${end_init}#" \
       ${locdir}/submit_diag.csh
sed -i -e "s#end_initTEMPLATE#${end_init}#" \
       -e "s#previousExpTEMPLATE#${prev_name}#" \
       -e "s#currentExpTEMPLATE#${curr_name}#" \
       ${locdir}/fc1diag.csh
# Create links so the forecast/DA directories are found by Junmei's scripts
ln -fs ${expdir_curr}/CyclingFC ${expdir_curr}/FC1
ln -fs ${expdir_curr}/CyclingDA ${expdir_curr}/DA
echo "nail 4:  ck locdir=$locdir for processed setup.csh; submit_diag.csh; fc1diag.csh "


#------------------------------------------------------------#
# S5. submit jobs for plotting 
#------------------------------------------------------------#
#
# Default email subject and body variables
status=ALERT
body='Cycling failure. Check logs.'
#
# Run the script that submits all the diagnostic jobs.
FD=${expdir_curr}/ts_fc1diag_1dim_ana/RMS/${curr_name}-expmgfs_day0p0_Tro_surface_pressure_RMS.png
cd $locdir
./submit_diag.csh
cycling_status=$?
#
#
echo "cycling_status = $cycling_status"
echo "locdir= $locdir; FD=$FD"
if [ $cycling_status == 0 ]; then
   # Check for existence of one of the plot png's
   # TODO: this is not a sufficient logical check, some files are missing
  a=0
  until [[ -f $FD ]]; do 
    echo "a = $a , wt pp plot job completion"
    sleep 1m
    a=$(( a+1 ))
    if [ $a -ge $tppmax ]; then
      echo "pp failed"; break
    fi
  done
fi
#
# Save diagnostics in dated archive_dir
archive_dir=${startdir}/${ARCHIVE_TOP_DIR}/$(date +"%Y%m%d")
mkdir -p ${archive_dir}
cp -rp ${expdir_curr}/ts_* ${archive_dir}
cp -rp ${expdir_curr}/FC1DIAG ${archive_dir}
cp -rp ${expdir_curr}/Verification ${archive_dir}
# rsync the plots to koa for display on a web page
# (TODO: Need to figure out how to get rsync working through cron.)
#/usr/bin/rsync -e '/usr/bin/ssh -vi /glade/u/home/${USER}/.ssh/koa-sync' -avz --exclude 'FC1DIAG' --exclude 'Verification'  ${startdir}/${ARCHIVE_TOP_DIR}/*  ${USER}@koa.mmm.ucar.edu:/exports/htdocs2/projects/DA_images/.


if [ $a -lt $tppmax ]; then
     body="${body} Plots successfully created."
     status=success
   else
     body="${body} Problem creating the plots."
fi
#
#
# Notify $email about what happened.
echo "Cycling cron script finished. Sending email."
mail -s "cylc cycling cron autotest $status" $email <<< "$body"
echo "nail 5:  end of wrap_autotest.sh"
exit
