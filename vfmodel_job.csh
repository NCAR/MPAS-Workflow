#!/bin/csh
#PBS -N vfmodelinDateArg_ExpNameArg
#PBS -A AccountNumArg
#PBS -q QueueNameArg
#PBS -l select=1:ncpus=18:mpiprocs=18
#PBS -l walltime=0:15:00
#PBS -m ae
#PBS -k eod
#PBS -o vfmodel.log.job.out 
#PBS -e vfmodel.log.job.err

#   #SBATCH --job-name=vfmodelinDateArg_ExpNameArg
#   #SBATCH --account=AccountNumberArg
#   #SBATCH --ntasks=1
#   #SBATCH --cpus-per-task=18
#   #SBATCH --mem=42G
#   #SBATCH --time=0:15:00
#   #SBATCH --partition=dav
#   #SBATCH --output=vfobs.log.job.out


date

#
# Setup environment:
# ================
source ./setup.csh

module load python/3.7.5

setenv cycle_Date       inDateArg
setenv self_StateDir    inStateDirArg
setenv self_StatePrefix inStatePrefixArg

#
# Time info:
# ==========
set yy = `echo ${cycle_Date} | cut -c 1-4`
set mm = `echo ${cycle_Date} | cut -c 5-6`
set dd = `echo ${cycle_Date} | cut -c 7-8`
set hh = `echo ${cycle_Date} | cut -c 9-10`

set fileDate = ${yy}-${mm}-${dd}_${hh}.00.00

#
# collect model-space diagnostic statistics into DB files:
# ========================================================
mkdir -p diagnostic_stats/model
cd diagnostic_stats/model
ln -sf ${self_StateDir}/${self_StatePrefix}.${fileDate}.nc ../

set mainScript="writediag_modelspace.py"
ln -fs ${pyModelDir}/*.py ./
ln -fs ${pyModelDir}/${mainScript} ./

setenv success 1
while ( $success != 0 )
  python ${mainScript} >& diags.log

  setenv success $?

  if ( $success != 0 ) then
    source /glade/u/apps/ch/opt/usr/bin/npl/ncar_pylib.csh
    sleep 3
  endif
end

cd -

date

exit
