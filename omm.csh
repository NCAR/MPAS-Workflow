#!/bin/csh
#  #PBS -N om_ExpNameArg
#  #PBS -A AccountNumberArg
#  #PBS -q QueueNameArg
#  #PBS -l select=NNODEArg:ncpus=NPEArg:mpiprocs=NPEArg:mem=109GB
#  #PBS -l walltime=0:10:00
#  #PBS -m ae
#  #PBS -k eod
#  #PBS -o log.job.out
#  #PBS -e log.job.err
#   #SBATCH --job-name=om_ExpNameArg
#   #SBATCH --account=AccountNumberArg
#   #SBATCH --ntasks=NNODEArg
#   #SBATCH --cpus-per-task=NPEArg
#   #SBATCH --mem=109G
#   #SBATCH --time=0:10:00
#   #SBATCH --partition=dav
#   #SBATCH --output=log.job.out

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
if ( ! $isInt) then
  echo "ERROR in $0 : ArgDT must be an integer, not $ArgDT"
  exit 1
endif
if ($ArgDT > 0 || "$ArgStateType" =~ "FC") then
  set self_WorkDir = $self_WorkDir/${ArgDT}hr
endif
set self_StateDir = $inStateDirsArg[$ArgMember]
set self_StatePrefix = inStatePrefixArg

echo "WorkDir = ${self_WorkDir}"

cd ${self_WorkDir}

#
# Time info for namelist, yaml etc:
# =============================================
set yy = `echo ${validDate} | cut -c 1-4`
set mm = `echo ${validDate} | cut -c 5-6`
set dd = `echo ${validDate} | cut -c 7-8`
set hh = `echo ${validDate} | cut -c 9-10`

set fileDate = ${yy}-${mm}-${dd}_${hh}.00.00

# Remove old logs
rm jedi.log*

#################################################################
# EVERYTHING BEYOND HERE MUST HAPPEN AFTER OMM STATE IS AVAILABLE
#################################################################

# Link/copy bg from other directory and ensure that MPASDiagVars are present
# =========================================================================
set other = $self_StateDir
set bg = ./${bgDir}
set an = ./${anDir}
mkdir -p ${bg}
mkdir -p ${an}

set bgFileOther = ${other}/${self_StatePrefix}.$fileDate.nc
set bgFileDA = ${bg}/${BGFilePrefix}.$fileDate.nc

set copyDiags = 0
foreach var ({$MPASDiagVars})
  ncdump -h ${bgFileOther} | grep $var
  if ( $status != 0 ) then
    @ copyDiags++
  endif 
end
if ( $copyDiags > 0 ) then
  ln -fsv ${bgFileOther} ${bgFileDA}_orig
  set diagFile = ${other}/${DIAGFilePrefix}.$fileDate.nc
  cp ${bgFileDA}_orig ${bgFileDA}

  # Copy diagnostic variables used in DA to bg
  # ==========================================
  ncks -A -v ${MPASDiagVars} ${diagFile} ${bgFileDA}
else
  ln -fsv ${bgFileOther} ${bgFileDA}
endif

# link one of the backgrounds to a local RST file
# used to initialize the MPAS mesh
ln -sf ${bgFileDA} ./${BGFilePrefix}.$fileDate.nc

#set other = $self_StateDir
#set bgFileOther = ${other}/${self_StatePrefix}.$fileDate.nc
#set bgFileDA = ./${BGFilePrefix}.$fileDate.nc
#
#set copyDiags = 0
#foreach var ({$MPASDiagVars})
#  ncdump -h ${bgFileOther} | grep $var
#  if ( $status != 0 ) then
#    @ copyDiags++
#  endif 
#end
#if ( $copyDiags > 0 ) then
#  ln -fsv ${bgFileOther} ${bgFileDA}_orig
#  set diagFile = ${other}/${DIAGFilePrefix}.$fileDate.nc
#  cp ${bgFileDA}_orig ${bgFileDA}
#
#  # Copy diagnostic variables used in DA to bg
#  # ==========================================
#  ncks -A -v ${MPASDiagVars} ${diagFile} ${bgFileDA}
#else
#  ln -fsv ${bgFileOther} ${bgFileDA}
#endif

# Remove existing analysis file, if any
# =====================================
set anFile = ${an}/${anStatePrefix}.${fileDate}.nc
rm ${anFile}

# ===================
# ===================
# Run the executable:
# ===================
# ===================
ln -sf ${JEDIBUILDDIR}/bin/${OMMEXE} ./
mpiexec ./${OMMEXE} ./jedi.yaml ./jedi.log >& jedi.log.all

#
# Check status:
# =============================================
#grep "Finished running the atmosphere core" log.atmosphere.0000.out
grep 'Run: Finishing oops.* with status = 0' jedi.log
if ( $status != 0 ) then
  touch ./FAIL
  echo "ERROR in $0 : jedi application failed" >> ./FAIL
  exit 1
endif

# Remove garbage analysis file
# ============================
rm ${anFile}

date

exit 0
