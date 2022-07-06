#!/bin/csh -f

if ( $?config_modeldata ) exit 0
set config_modeldata = 1

source config/workflow.csh
source config/model.csh
source config/experiment.csh
source config/externalanalyses.csh
source config/firstbackground.csh
set wd = `pwd`
source config/tools.csh $wd

## file date for first background
set yy = `echo ${FirstCycleDate} | cut -c 1-4`
set mm = `echo ${FirstCycleDate} | cut -c 5-6`
set dd = `echo ${FirstCycleDate} | cut -c 7-8`
set hh = `echo ${FirstCycleDate} | cut -c 9-10`
setenv FirstFileDate ${yy}-${mm}-${dd}_${hh}.00.00


## sea/ocean surface files
setenv seaMaxMembers 20
setenv deterministicSeaAnaDir ${externalanalyses__externalDirectory}
if ( $nMembers > 1 ) then
  # using member-specific sst/xice data from GEFS
  # 60km and 120km
  setenv SeaAnaDir /glade/p/mmm/parc/guerrett/pandac/fixed_input/GEFS/surface/000hr/${model__precision}
  setenv seaMemFmt "/{:02d}"
else
  # deterministic
  # 60km and 120km
  setenv SeaAnaDir ${deterministicSeaAnaDir}
  setenv seaMemFmt " "
endif

setenv StaticFieldsDirOuter `echo "$firstbackground__staticDirectoryOuter" \
  | sed 's@{{ExternalAnalysisWorkDir}}@'${ExternalAnalysisWorkDir}'@' \
  | sed 's@{{FirstCycleDate}}@'${FirstCycleDate}'@' \
  `
setenv StaticFieldsDirInner `echo "$firstbackground__staticDirectoryInner" \
  | sed 's@{{ExternalAnalysisWorkDir}}@'${ExternalAnalysisWorkDirInner}'@' \
  | sed 's@{{FirstCycleDate}}@'${FirstCycleDate}'@' \
  `
setenv StaticFieldsDirEnsemble `echo "$firstbackground__staticDirectoryEnsemble" \
  | sed 's@{{ExternalAnalysisWorkDir}}@'${ExternalAnalysisWorkDirEnsemble}'@' \
  | sed 's@{{FirstCycleDate}}@'${FirstCycleDate}'@' \
  `

setenv staticMemFmt "${firstbackground__memberFormatOuter}"

setenv StaticFieldsFileOuter ${firstbackground__staticPrefixOuter}.${FirstFileDate}.nc
setenv StaticFieldsFileInner ${firstbackground__staticPrefixInner}.${FirstFileDate}.nc
setenv StaticFieldsFileEnsemble ${firstbackground__staticPrefixEnsemble}.${FirstFileDate}.nc
