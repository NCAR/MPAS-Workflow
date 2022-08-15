#!/bin/csh -f

# usage: source getCycleVars.csh

# requires thisCycleDate and thisValidDate to be set externally

source config/tools.csh
source config/auto/members.csh
source config/auto/model.csh
source config/auto/naming.csh
source config/auto/workflow.csh

set prevCycleDate = `$advanceCYMDH ${thisCycleDate} -${CyclingWindowHR}`
#set nextCycleDate = `$advanceCYMDH ${thisCycleDate} ${CyclingWindowHR}`
setenv prevCycleDate ${prevCycleDate}
#setenv nextCycleDate ${nextCycleDate}

## setup cycle directory names
set ObsDir = ${ObservationsWorkDir}/${thisValidDate}
set CyclingDADir = ${VariationalWorkDir}/${thisCycleDate}
set CyclingDAInDir = $CyclingDADir/${backgroundSubDir}
set CyclingDAOutDir = $CyclingDADir/${analysisSubDir}
set CyclingDADirs = (${CyclingDADir})
set BenchmarkCyclingDADirs = (${BenchmarkVariationalWorkDir}/${thisCycleDate})

set ExternalAnalysisDir = ${ExternalAnalysesWorkDir}/${thisValidDate}
set ExternalAnalysisDirOuter = ${ExternalAnalysesWorkDir}/${outerMesh}/${thisValidDate}
set ExternalAnalysisDirInner = ${ExternalAnalysesWorkDir}/${innerMesh}/${thisValidDate}
set ExternalAnalysisDirEnsemble = ${ExternalAnalysesWorkDir}/${ensembleMesh}/${thisValidDate}

set prevCyclingDADir = ${VariationalWorkDir}/${prevCycleDate}
set CyclingFCDir = ${ForecastWorkDir}/${thisCycleDate}
set prevCyclingFCDir = ${ForecastWorkDir}/${prevCycleDate}
set ExtendedFCDir = ${ExtendedForecastWorkDir}/${thisCycleDate}

set memDir = /mean
set MeanBackgroundDirs = (${CyclingDAInDir}${memDir})
set MeanAnalysisDirs = (${CyclingDAOutDir}${memDir})
set ExtendedMeanFCDirs = (${ExtendedFCDir}${memDir})

set VerifyEnsMeanBGDirs = (${VerifyObsWorkDir}/${backgroundSubDir}${memDir}/${thisCycleDate})
set VerifyMeanANDirs = (${VerifyObsWorkDir}/${analysisSubDir}${memDir}/${thisCycleDate})
set VerifyMeanFCDirs = (${VerifyObsWorkDir}/${forecastSubDir}${memDir}/${thisCycleDate})

#set BenchmarkVerifyEnsMeanBGDirs = (${BenchmarkVerifyObsWorkDir}/${backgroundSubDir}${memDir}/${thisCycleDate})
#set BenchmarkVerifyMeanANDirs = (${BenchmarkVerifyObsWorkDir}/${analysisSubDir}${memDir}/${thisCycleDate})
#set BenchmarkVerifyMeanFCDirs = (${BenchmarkVerifyObsWorkDir}/${forecastSubDir}${memDir}/${thisCycleDate})

set CyclingRTPPDir = ${RTPPWorkDir}/${thisCycleDate}
set CyclingABEInflationDir = ${ABEIWorkDir}/${thisCycleDate}

set CyclingDAInDirs = ()
set CyclingDAOutDirs = ()

set CyclingFCDirs = ()
set ExternalAnalysisDirOuters = ()
set prevCyclingFCDirs = ()

set ExtendedEnsFCDirs = ()

set VerifyBGPrefix = ${VerifyObsWorkDir}/${backgroundSubDir}
set VerifyBGDirs = ()
set VerifyANPrefix = ${VerifyObsWorkDir}/${analysisSubDir}
set VerifyANDirs = ()
set VerifyEnsFCDirs = ()

set BenchmarkVerifyBGPrefix = ${BenchmarkVerifyObsWorkDir}/${backgroundSubDir}
set BenchmarkVerifyBGDirs = ()
set BenchmarkVerifyANPrefix = ${BenchmarkVerifyObsWorkDir}/${analysisSubDir}
set BenchmarkVerifyANDirs = ()
set BenchmarkVerifyEnsFCDirs = ()

set member = 1
while ( $member <= ${nMembers} )
  set memDir = `${memberDir} $nMembers $member`
  set CyclingDAInDirs = ($CyclingDAInDirs ${CyclingDAInDir}${memDir})
  set CyclingDAOutDirs = ($CyclingDAOutDirs ${CyclingDAOutDir}${memDir})

  set CyclingFCDirs = ($CyclingFCDirs ${CyclingFCDir}${memDir})
  set ExternalAnalysisDirOuters = ($ExternalAnalysisDirOuters ${ExternalAnalysisDirOuter}${memDir})
  set prevCyclingFCDirs = ($prevCyclingFCDirs ${prevCyclingFCDir}${memDir})

  set ExtendedEnsFCDirs = ($ExtendedEnsFCDirs ${ExtendedFCDir}${memDir})

  set VerifyANDirs = ($VerifyANDirs ${VerifyANPrefix}${memDir}/${thisCycleDate})
  set VerifyBGDirs = ($VerifyBGDirs ${VerifyBGPrefix}${memDir}/${thisCycleDate})
  set VerifyEnsFCDirs = ($VerifyEnsFCDirs ${VerifyObsWorkDir}/${forecastSubDir}${memDir}/${thisCycleDate})

  set BenchmarkVerifyANDirs = ($BenchmarkVerifyANDirs ${BenchmarkVerifyANPrefix}${memDir}/${thisCycleDate})
  set BenchmarkVerifyBGDirs = ($BenchmarkVerifyBGDirs ${BenchmarkVerifyBGPrefix}${memDir}/${thisCycleDate})
  set BenchmarkVerifyEnsFCDirs = ($BenchmarkVerifyEnsFCDirs ${BenchmarkVerifyObsWorkDir}/${forecastSubDir}${memDir}/${thisCycleDate})

  @ member++
end

# Universal time info for namelist, yaml etc
# ==========================================
set yy = `echo ${thisValidDate} | cut -c 1-4`
set mm = `echo ${thisValidDate} | cut -c 5-6`
set dd = `echo ${thisValidDate} | cut -c 7-8`
set hh = `echo ${thisValidDate} | cut -c 9-10`
set thisMPASFileDate = ${yy}-${mm}-${dd}_${hh}.00.00
set thisMPASNamelistDate = ${yy}-${mm}-${dd}_${hh}:00:00
set thisISO8601Date = ${yy}-${mm}-${dd}T${hh}:00:00Z
set ICfileDate = ${yy}-${mm}-${dd}_${hh}
