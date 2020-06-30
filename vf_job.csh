#!/bin/csh
#PBS -N vfCDATE_EXPNAME
#PBS -A ACCOUNTNUM
#PBS -q QUEUENAME
#PBS -l select=1:ncpus=18:mpiprocs=18
#PBS -l walltime=0:15:00
#PBS -m ae
#PBS -k eod
#PBS -o vf.log.job.out 
#PBS -e vf.log.job.err

date

#
# set environment:
# ====================================
source ./setup.csh

module load python/3.7.5

#
# collect obs statistics into DB files
# ====================================
mkdir diagnostic_stats
cd diagnostic_stats

set mainScript="writediagstats_obsspace.py"
ln -fs ${pyScriptDir}/${mainScript} ./
ln -fs ${pyScriptDir}/*.py ./
set NUMPROC=`cat $PBS_NODEFILE | wc -l`

setenv success 1
while ( $success != 0 )
  mv diags.log diags.log_LAST

  ## MULTIPLE PROCESSORS
  python ${mainScript} -n ${NUMPROC} -p ../${DBDir} -o ${obsPrefix} -g ${geoPrefix} -d ${diagPrefix} >& diags.log

  setenv success $?

  if ( $success != 0 ) then
    source /glade/u/apps/ch/opt/usr/bin/npl/ncar_pylib.csh
    sleep 3
  endif
end

deactivate

date

exit
