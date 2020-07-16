#!/bin/csh
#PBS -N omStateTypeArginDateArg_ExpNameArg
#PBS -A AccountNumberArg
#PBS -q QueueNameArg
#PBS -l select=NNODE:ncpus=NPE:mpiprocs=NPE:mem=109GB
#PBS -m ae
#PBS -k eod
#PBS -o log.job.out
#PBS -e log.job.err

date

#
#set environment:
# =============================================
source ./setup.csh

setenv self_Date          inDateArg
setenv self_StateDirs   (inStateDirsArg)
setenv self_StatePrefix inStatePrefixArg

if ( ${#self_StateDirs} != 1 ) then
  echo "ERROR in $0 : self_StateDirs must be == 1"
  exit 1
endif

#
# Time info for namelist, yaml etc:
# =============================================
set yy = `echo ${self_Date} | cut -c 1-4`
set mm = `echo ${self_Date} | cut -c 5-6`
set dd = `echo ${self_Date} | cut -c 7-8`
set hh = `echo ${self_Date} | cut -c 9-10`

set fileDate = ${yy}-${mm}-${dd}_${hh}.00.00

# Remove old logs
rm jedi.log*

#################################################################
# EVERYTHING BEYOND HERE MUST HAPPEN AFTER OMM STATE IS AVAILABLE
#################################################################

# Link/copy bg from other directory and ensure that MPASDiagVars are present
# =========================================================================

set memDir = `${memberDir} ${omm} 0`
set other = ${self_StateDirs[1]}${memDir}
set bgFileOther = ${other}/${self_StatePrefix}.$fileDate.nc
set bgFileDA = ./${BGFilePrefix}.$fileDate.nc

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

# Remove existing analysis file, if any
# =====================================
set anFile = ${anStatePrefix}.${fileDate}.nc
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
