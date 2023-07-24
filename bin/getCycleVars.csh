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

#source config/auto/variational.csh

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

# Set time info for subwindow
if ("$subwindow" == "3") then
  set window_dt = `echo ${subwindow}`
  set windowDate1 = "`$advanceCYMDH ${thisCycleDate} -${window_dt}`"
  set windowDate3 = "`$advanceCYMDH ${thisCycleDate} ${window_dt}`"

  set yy1 = `echo ${windowDate1} | cut -c 1-4`
  set mm1 = `echo ${windowDate1} | cut -c 5-6`
  set dd1 = `echo ${windowDate1} | cut -c 7-8`
  set hh1 = `echo ${windowDate1} | cut -c 9-10`
  set yy3 = `echo ${windowDate3} | cut -c 1-4`
  set mm3 = `echo ${windowDate3} | cut -c 5-6`
  set dd3 = `echo ${windowDate3} | cut -c 7-8`
  set hh3 = `echo ${windowDate3} | cut -c 9-10`

  set thisMPASFileDate1 = ${yy1}-${mm1}-${dd1}_${hh1}.00.00
  set thisISO8601Date1 = ${yy1}-${mm1}-${dd1}T${hh1}:00:00Z
  set thisMPASFileDate3 = ${yy3}-${mm3}-${dd3}_${hh3}.00.00
  set thisISO8601Date3 = ${yy3}-${mm3}-${dd3}T${hh3}:00:00Z
endif

if ("$subwindow" == "1") then
  set window_dt = `echo ${subwindow}`
  set windowDate1 = "`$advanceCYMDH ${thisCycleDate} -3`"
  set windowDate2 = "`$advanceCYMDH ${thisCycleDate} -2`"
  set windowDate3 = "`$advanceCYMDH ${thisCycleDate} -1`"
  set windowDate5 = "`$advanceCYMDH ${thisCycleDate} 1`"
  set windowDate6 = "`$advanceCYMDH ${thisCycleDate} 2`"
  set windowDate7 = "`$advanceCYMDH ${thisCycleDate} 3`"

  set yy1 = `echo ${windowDate1} | cut -c 1-4`
  set mm1 = `echo ${windowDate1} | cut -c 5-6`
  set dd1 = `echo ${windowDate1} | cut -c 7-8`
  set hh1 = `echo ${windowDate1} | cut -c 9-10`
  set yy2 = `echo ${windowDate2} | cut -c 1-4`
  set mm2 = `echo ${windowDate2} | cut -c 5-6`
  set dd2 = `echo ${windowDate2} | cut -c 7-8`
  set hh2 = `echo ${windowDate2} | cut -c 9-10`
  set yy3 = `echo ${windowDate3} | cut -c 1-4`
  set mm3 = `echo ${windowDate3} | cut -c 5-6`
  set dd3 = `echo ${windowDate3} | cut -c 7-8`
  set hh3 = `echo ${windowDate3} | cut -c 9-10`
  set yy5 = `echo ${windowDate5} | cut -c 1-4`
  set mm5 = `echo ${windowDate5} | cut -c 5-6`
  set dd5 = `echo ${windowDate5} | cut -c 7-8`
  set hh5 = `echo ${windowDate5} | cut -c 9-10`
  set yy6 = `echo ${windowDate6} | cut -c 1-4`
  set mm6 = `echo ${windowDate6} | cut -c 5-6`
  set dd6 = `echo ${windowDate6} | cut -c 7-8`
  set hh6 = `echo ${windowDate6} | cut -c 9-10`
  set yy7 = `echo ${windowDate7} | cut -c 1-4`
  set mm7 = `echo ${windowDate7} | cut -c 5-6`
  set dd7 = `echo ${windowDate7} | cut -c 7-8`
  set hh7 = `echo ${windowDate7} | cut -c 9-10`

  set thisMPASFileDate1 = ${yy1}-${mm1}-${dd1}_${hh1}.00.00
  set thisISO8601Date1 = ${yy1}-${mm1}-${dd1}T${hh1}:00:00Z
  set thisMPASFileDate2 = ${yy2}-${mm2}-${dd2}_${hh2}.00.00
  set thisISO8601Date2 = ${yy2}-${mm2}-${dd2}T${hh2}:00:00Z
  set thisMPASFileDate3 = ${yy3}-${mm3}-${dd3}_${hh3}.00.00
  set thisISO8601Date3 = ${yy3}-${mm3}-${dd3}T${hh3}:00:00Z
  set thisMPASFileDate5 = ${yy5}-${mm5}-${dd5}_${hh5}.00.00
  set thisISO8601Date5 = ${yy5}-${mm5}-${dd5}T${hh5}:00:00Z
  set thisMPASFileDate6 = ${yy6}-${mm6}-${dd6}_${hh6}.00.00
  set thisISO8601Date6 = ${yy6}-${mm6}-${dd6}T${hh6}:00:00Z
  set thisMPASFileDate7 = ${yy7}-${mm7}-${dd7}_${hh7}.00.00
  set thisISO8601Date7 = ${yy7}-${mm7}-${dd7}T${hh7}:00:00Z
endif

# Date-dependent directory names
# ==============================

## DA
set CyclingDADir = ${DAWorkDir}/${thisCycleDate}
set CyclingDAInDir = $CyclingDADir/${backgroundSubDir}
set CyclingDAOutDir = $CyclingDADir/${analysisSubDir}
set CyclingDADirs = (${CyclingDADir})
set BenchmarkCyclingDADirs = (${BenchmarkDAWorkDir}/${thisCycleDate})

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
