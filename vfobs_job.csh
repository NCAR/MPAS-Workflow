#!/bin/csh
#  #PBS -N vfobs_ExpNameArg
#  #PBS -A AccountNumArg
#  #PBS -q QueueNameArg
#  #PBS -l select=1:ncpus=18:mpiprocs=18
#  #PBS -l walltime=0:15:00
#  #PBS -m ae
#  #PBS -k eod
#  #PBS -o vfobs.log.job.out 
#  #PBS -e vfobs.log.job.err
#   #SBATCH --job-name=vfobs_ExpNameArg
#   #SBATCH --account=AccountNumberArg
#   #SBATCH --ntasks=1
#   #SBATCH --cpus-per-task=18
#   #SBATCH --mem=42G
#   #SBATCH --time=0:15:00
#   #SBATCH --partition=dav
#   #SBATCH --output=vfobs.log.job.out

date

set ArgMember = "$1"
set ArgDT = "$2"
set ArgStateType = "$3"

#
# Setup environment:
# =============================================
source ./control.csh
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set cycle_Date = ${yymmdd}${hh}
set validDate = `$advanceCYMDH ${cycle_Date} ${ArgDT}`
source ./getCycleDirectories.csh

set test = `echo $ArgMember | grep '^[0-9]*$'`
set isInt = (! $status)
if ( $isInt && "$ArgMember" != "0") then
  set self_WorkDir = $WorkDirsArg[$ArgMember]
else
  set self_WorkDir = $WorkDirsArg
endif
set test = `echo $ArgDT | grep '^[0-9]*$'`
set isInt = (! $status)
if ( ! $IsInt) then
  echo "ERROR in $0 : ArgDT must be an integer, not $ArgDT"
  exit 1
endif
if ($ArgDT > 0 || "$ArgStateType" =~ "FC") then
  set self_WorkDir = $self_WorkDir/${ArgDT}hr
endif

module load python/3.7.5

cd ${self_WorkDir}

#
# collect obs-space diagnostic statistics into DB files:
# ======================================================
mkdir -p diagnostic_stats/obs
cd diagnostic_stats/obs

set mainScript="writediagstats_obsspace.py"
ln -fs ${pyObsDir}/*.py ./
ln -fs ${pyObsDir}/${mainScript} ./
set NUMPROC=`cat $PBS_NODEFILE | wc -l`

set success = 1
while ( $success != 0 )
  mv diags.log diags.log_LAST

  ## MULTIPLE PROCESSORS
  python ${mainScript} -n ${NUMPROC} -p ../../${OutDBDir} -o ${obsPrefix} -g ${geoPrefix} -d ${diagPrefix} >& diags.log

  set success = $?

  if ( $success != 0 ) then
    source /glade/u/apps/ch/opt/usr/bin/npl/ncar_pylib.csh
    sleep 3
  endif
end
cd -

date

exit
