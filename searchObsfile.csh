#!/bin/csh -f
# Search for observations files on RDA

date

# Setup environment
# =================
source config/experiment.csh
source config/filestructure.csh
source config/tools.csh
source config/modeldata.csh
source config/builds.csh
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set ccyy = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c1-4`
set mmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c5-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}
set thisValidDate = ${thisCycleDate}
source ./getCycleVars.csh

# ================================================================================================

foreach inst ( ${preprocessObsList} )

  if ( ${inst} == satwnd ) then
     setenv THIS_FILE ${RDAdataDir}/ds351.0/bufr/${ccyy}/gdas.${inst}.t${hh}z.${ccyy}${mmdd}.bufr
     if ( -e ${THIS_FILE}) then
        echo "${THIS_FILE} exists"
     else
        echo "Waiting for ${THIS_FILE} to exist"
        sleep 10m
     endif
  else if ( ${inst} == prepbufr ) then
     setenv THIS_FILE ${RDAdataDir}/ds337.0/prep48h/${ccyy}/prepbufr.gdas.${ccyy}${mmdd}.t${hh}z.nr.48h
     if ( -e ${THIS_FILE}) then
        echo "${THIS_FILE} exists"
     else
        echo "Waiting for ${THIS_FILE} to exist"
        sleep 10m
     endif
  else
     set THIS_TAR_FILE = ${RDAdataDir}/ds735.0/${inst}/${ccyy}/${inst}.${ccyy}${mmdd}.tar.gz
     if ( ${inst} == 'cris' && ${ccyy} >= '2021' ) then
        # cris file name became crisf4 since 2021
        set THIS_TAR_FILE = ${RDAdataDir}/ds735.0/${inst}/${ccyy}/${inst}f4.${ccyy}${mmdd}.tar.gz
     endif
     if ( -e ${THIS_TAR_FILE}) then
        echo "${THIS_TAR_FILE} exists"
     else
        echo "Waiting for ${THIS_FILE} to exist"
        sleep 10m
     endif
  endif


exit 0
