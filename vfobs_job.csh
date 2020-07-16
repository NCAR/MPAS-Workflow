#!/bin/csh
#PBS -N vfobsinDateArg_ExpNameArg
#PBS -A AccountNumArg
#PBS -q QueueNameArg
#PBS -l select=1:ncpus=18:mpiprocs=18
#PBS -l walltime=0:15:00
#PBS -m ae
#PBS -k eod
#PBS -o vfobs.log.job.out 
#PBS -e vfobs.log.job.err

date

#
# Setup environment:
# ================
source ./setup.csh

module load python/3.7.5

#
# collect obs-space diagnostic statistics into DB files:
# ======================================================
mkdir -p diagnostic_stats/obs
cd diagnostic_stats/obs

set mainScript="writediagstats_obsspace.py"
ln -fs ${pyObsDir}/*.py ./
ln -fs ${pyObsDir}/${mainScript} ./
set NUMPROC=`cat $PBS_NODEFILE | wc -l`

setenv success 1
while ( $success != 0 )
  mv diags.log diags.log_LAST

  ## MULTIPLE PROCESSORS
  python ${mainScript} -n ${NUMPROC} -p ../../${OutDBDir} -o ${obsPrefix} -g ${geoPrefix} -d ${diagPrefix} >& diags.log

  setenv success $?

  if ( $success != 0 ) then
    source /glade/u/apps/ch/opt/usr/bin/npl/ncar_pylib.csh
    sleep 3
  endif
end
cd -

date

exit
