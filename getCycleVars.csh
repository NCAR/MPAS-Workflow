#!/bin/csh -f

source config/filestructure.csh
source config/tools.csh

set prevCycleDate = `$advanceCYMDH ${thisCycleDate} -${CyclingWindowHR}`
#set nextCycleDate = `$advanceCYMDH ${thisCycleDate} ${CyclingWindowHR}`
setenv prevCycleDate ${prevCycleDate}
#setenv nextCycleDate ${nextCycleDate}

## setup cycle directory names
set CyclingDADirs = (${CyclingDAWorkDir}/${thisCycleDate})
set BenchmarkCyclingDADirs = (${BenchmarkCyclingDAWorkDir}/${thisCycleDate})
set CyclingDAInDir = $CyclingDADirs[1]/${bgDir}
set CyclingDAOutDir = $CyclingDADirs[1]/${anDir}

set prevCyclingDADir = ${CyclingDAWorkDir}/${prevCycleDate}
set CyclingFCDir = ${CyclingFCWorkDir}/${thisCycleDate}
set prevCyclingFCDir = ${CyclingFCWorkDir}/${prevCycleDate}
set ExtendedFCDir = ${ExtendedFCWorkDir}/${thisCycleDate}

set memDir = /mean
set MeanBackgroundDirs = (${CyclingDAInDir}${memDir})
set MeanAnalysisDirs = (${CyclingDAOutDir}${memDir})
set ExtendedMeanFCDirs = (${ExtendedFCDir}${memDir})
set VerifyEnsMeanBGDirs = (${VerificationWorkDir}/${bgDir}${memDir}/${thisCycleDate})
set VerifyMeanANDirs = (${VerificationWorkDir}/${anDir}${memDir}/${thisCycleDate})
set VerifyMeanFCDirs = (${VerificationWorkDir}/${fcDir}${memDir}/${thisCycleDate})

#set BenchmarkVerifyEnsMeanBGDirs = (${BenchmarkVerificationWorkDir}/${bgDir}${memDir}/${thisCycleDate})
#set BenchmarkVerifyMeanANDirs = (${BenchmarkVerificationWorkDir}/${anDir}${memDir}/${thisCycleDate})
#set BenchmarkVerifyMeanFCDirs = (${BenchmarkVerificationWorkDir}/${fcDir}${memDir}/${thisCycleDate})

set CyclingRTPPInflationDir = ${RTPPInflationWorkDir}/${thisCycleDate}
set CyclingABEInflationDir = ${ABEInflationWorkDir}/${thisCycleDate}

set CyclingDAInDirs = ()
set CyclingDAOutDirs = ()

set CyclingFCDirs = ()
set prevCyclingFCDirs = ()

set ExtendedEnsFCDirs = ()

set VerifyBGPrefix = ${VerificationWorkDir}/${bgDir}
set VerifyBGDirs = ()
set VerifyANPrefix = ${VerificationWorkDir}/${anDir}
set VerifyANDirs = ()
set VerifyEnsFCDirs = ()

set BenchmarkVerifyBGPrefix = ${BenchmarkVerificationWorkDir}/${bgDir}
set BenchmarkVerifyBGDirs = ()
set BenchmarkVerifyANPrefix = ${BenchmarkVerificationWorkDir}/${anDir}
set BenchmarkVerifyANDirs = ()
set BenchmarkVerifyEnsFCDirs = ()

set member = 1
while ( $member <= ${nEnsDAMembers} )
  set memDir = `${memberDir} $DAType $member`
  set CyclingDAInDirs = ($CyclingDAInDirs ${CyclingDAInDir}${memDir})
  set CyclingDAOutDirs = ($CyclingDAOutDirs ${CyclingDAOutDir}${memDir})

  set CyclingFCDirs = ($CyclingFCDirs ${CyclingFCDir}${memDir})
  set prevCyclingFCDirs = ($prevCyclingFCDirs ${prevCyclingFCDir}${memDir})

  set ExtendedEnsFCDirs = ($ExtendedEnsFCDirs ${ExtendedFCDir}${memDir})

  set VerifyANDirs = ($VerifyANDirs ${VerifyANPrefix}${memDir}/${thisCycleDate})
  set VerifyBGDirs = ($VerifyBGDirs ${VerifyBGPrefix}${memDir}/${thisCycleDate})
  set VerifyEnsFCDirs = ($VerifyEnsFCDirs ${VerificationWorkDir}/${fcDir}${memDir}/${thisCycleDate})

  set BenchmarkVerifyANDirs = ($BenchmarkVerifyANDirs ${BenchmarkVerifyANPrefix}${memDir}/${thisCycleDate})
  set BenchmarkVerifyBGDirs = ($BenchmarkVerifyBGDirs ${BenchmarkVerifyBGPrefix}${memDir}/${thisCycleDate})
  set BenchmarkVerifyEnsFCDirs = ($BenchmarkVerifyEnsFCDirs ${BenchmarkVerificationWorkDir}/${fcDir}${memDir}/${thisCycleDate})

  @ member++
end

set ObsDiagnosticsDir = diagnostic_stats/obs
set ModelDiagnosticsDir = diagnostic_stats/model

set ObsCompareDir = Compare2Benchmark/obs
set ModelCompareDir = Compare2Benchmark/model

# Universal time info for namelist, yaml etc
# ==========================================
set yy = `echo ${thisValidDate} | cut -c 1-4`
set mm = `echo ${thisValidDate} | cut -c 5-6`
set dd = `echo ${thisValidDate} | cut -c 7-8`
set hh = `echo ${thisValidDate} | cut -c 9-10`
set fileDate = ${yy}-${mm}-${dd}_${hh}.00.00
set NMLDate = ${yy}-${mm}-${dd}_${hh}:00:00
set ConfDate = ${yy}-${mm}-${dd}T${hh}:00:00Z
