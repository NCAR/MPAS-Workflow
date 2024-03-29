#!/bin/csh -f

# (C) Copyright 2023 UCAR
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

# Process arguments
# =================
## args
# ArgWorkDir: my location
set ArgWorkDir = "$1"

date

# Setup environment
# =================
source config/auto/experiment.csh
source config/auto/rtpp.csh
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}
set thisValidDate = ${thisCycleDate}
source ./bin/getCycleVars.csh

# static work directory
set self_WorkDir = "${ExperimentDirectory}/"`echo "$ArgWorkDir" \
  | sed 's@{{thisCycleDate}}@'${thisCycleDate}'@' \
  `
echo "WorkDir = ${self_WorkDir}"
cd ${self_WorkDir}

# ================================================================================================

# Remove original analyses before RTPP
# ====================================
if ("${retainOriginalAnalyses}" == False) then
  rm -r ${analysisSubDir}BeforeRTPP
endif

date

exit 0
