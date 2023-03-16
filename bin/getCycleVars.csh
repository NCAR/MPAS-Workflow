#!/bin/csh -f

# (C) Copyright 2023 UCAR
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

# usage: source getCycleVars.csh

# requires thisCycleDate and thisValidDate to be set externally

source config/tools.csh
source config/auto/members.csh
source config/auto/naming.csh
source config/auto/workflow.csh

# Universal time info for namelist, yaml etc
# ==========================================
setenv prevCycleDate "`$advanceCYMDH ${thisCycleDate} -${CyclingWindowHR}`"
setenv nextCycleDate "`$advanceCYMDH ${thisCycleDate} ${CyclingWindowHR}`"

set yy = `echo ${thisValidDate} | cut -c 1-4`
set mm = `echo ${thisValidDate} | cut -c 5-6`
set dd = `echo ${thisValidDate} | cut -c 7-8`
set hh = `echo ${thisValidDate} | cut -c 9-10`
set thisMPASFileDate = ${yy}-${mm}-${dd}_${hh}.00.00
set thisMPASNamelistDate = ${yy}-${mm}-${dd}_${hh}:00:00
set thisISO8601Date = ${yy}-${mm}-${dd}T${hh}:00:00Z

# Date-dependent directory names
# ==============================

## DA
# Variational
set CyclingDADir = ${VariationalWorkDir}/${thisCycleDate}
set CyclingDAInDir = $CyclingDADir/${backgroundSubDir}
set CyclingDAOutDir = $CyclingDADir/${analysisSubDir}
set CyclingDADirs = (${CyclingDADir})
set BenchmarkCyclingDADirs = (${BenchmarkVariationalWorkDir}/${thisCycleDate})

set memDir = /mean
set MeanBackgroundDirs = (${CyclingDAInDir}${memDir})
set MeanAnalysisDirs = (${CyclingDAOutDir}${memDir})

set CyclingDAInDirs = ()
set CyclingDAOutDirs = ()
set member = 1
while ( $member <= ${nMembers} )
  set memDir = `${memberDir} $nMembers $member`
  set CyclingDAInDirs = ($CyclingDAInDirs ${CyclingDAInDir}${memDir})
  set CyclingDAOutDirs = ($CyclingDAOutDirs ${CyclingDAOutDir}${memDir})
  @ member++
end

# ABEI
set CyclingABEInflationDir = ${ABEIWorkDir}/${thisCycleDate}

## Forecast
set CyclingFCDir = ${ForecastWorkDir}/${thisCycleDate}
set prevCyclingFCDir = ${ForecastWorkDir}/${prevCycleDate}

set CyclingFCDirs = ()
set prevCyclingFCDirs = ()
set member = 1
while ( $member <= ${nMembers} )
  set memDir = `${memberDir} $nMembers $member`
  set CyclingFCDirs = ($CyclingFCDirs ${CyclingFCDir}${memDir})
  set prevCyclingFCDirs = ($prevCyclingFCDirs ${prevCyclingFCDir}${memDir})
  @ member++
end

## BenchmarkVerify*
set memDir = /mean
set BenchmarkVerifyBGPrefix = ${BenchmarkVerifyObsWorkDir}/${backgroundSubDir}
set BenchmarkVerifyANPrefix = ${BenchmarkVerifyObsWorkDir}/${analysisSubDir}

set BenchmarkVerifyBGDirs = ()
set BenchmarkVerifyANDirs = ()
set BenchmarkVerifyEnsFCDirs = ()
set member = 1
while ( $member <= ${nMembers} )
  set memDir = `${memberDir} $nMembers $member`
  set BenchmarkVerifyANDirs = ($BenchmarkVerifyANDirs ${BenchmarkVerifyANPrefix}${memDir}/${thisCycleDate})
  set BenchmarkVerifyBGDirs = ($BenchmarkVerifyBGDirs ${BenchmarkVerifyBGPrefix}${memDir}/${thisCycleDate})
  set BenchmarkVerifyEnsFCDirs = ($BenchmarkVerifyEnsFCDirs ${BenchmarkVerifyObsWorkDir}/${forecastSubDir}${memDir}/${thisCycleDate})
  @ member++
end
