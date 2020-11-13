#!/bin/csh -f
set prevCycleDate = `$advanceCYMDH ${thisCycleDate} -${CyclingWindowHR}`
#set nextCycleDate = `$advanceCYMDH ${thisCycleDate} ${CyclingWindowHR}`
setenv prevCycleDate ${prevCycleDate}
#setenv nextCycleDate ${nextCycleDate}

## setup cycle directory names
set CyclingDADir = ${CyclingDAWorkDir}/${thisCycleDate}
set CyclingDAInDir = ${CyclingDADir}/${bgDir}
set CyclingDAOutDir = ${CyclingDADir}/${anDir}

set prevCyclingDADir = ${CyclingDAWorkDir}/${prevCycleDate}
set CyclingFCDir = ${CyclingFCWorkDir}/${thisCycleDate}
set prevCyclingFCDir = ${CyclingFCWorkDir}/${prevCycleDate}
set ExtendedFCDir = ${ExtendedFCWorkDir}/${thisCycleDate}

set memDir = /mean
set MeanBackgroundDir = ${CyclingDAInDir}${memDir}
set MeanAnalysisDir = ${CyclingDAOutDir}${memDir}
set ExtendedMeanFCDir = ${ExtendedFCDir}${memDir}
set VerifyEnsMeanBGDirs = ${VerificationWorkDir}/${bgDir}${memDir}/${thisCycleDate}
set VerifyMeanANDirs = ${VerificationWorkDir}/${anDir}${memDir}/${thisCycleDate}
set VerifyMeanFCDirs = ${VerificationWorkDir}/${fcDir}${memDir}/${thisCycleDate}

set CyclingInflationDir = ${CyclingInflationWorkDir}/${thisCycleDate}

set CyclingDAInDirs = ()
set CyclingDAOutDirs = ()
set CyclingFCDirs = ()
set prevCyclingFCDirs = ()
set ExtendedEnsFCDirs = ()

set VerifyBGDirs = ()
set VerifyANDirs = ()
set VerifyEnsFCDirs = ()
#set VerifyBGInDirs = ()
#set VerifyANInDirs = ()
#set VerifyEnsFCInDirs = ()
#set VerifyBGOutDirs = ()
#set VerifyANOutDirs = ()
#set VerifyEnsFCOutDirs = ()

#set VerifyFirstBGDirs = ()

set member = 1
set VerifyBGPrefix = ${VerificationWorkDir}/${bgDir}
set VerifyANPrefix = ${VerificationWorkDir}/${anDir}
#set VerifyObsDAEnsFmt = "${CyclingDADir}/${OutDBDir}${oopsMemFmt}"
#set VerifyObsBGEnsFmt = "${VerifyBGPrefix}${oopsMemFmt}/${thisCycleDate}/${OutDBDir}"
#set VerifyObsANEnsFmt = "${VerifyANPrefix}${oopsMemFmt}/${thisCycleDate}/${OutDBDir}"
#echo "VerifyObsDAEnsFmt = ${VerifyObsDAEnsFmt}"
#echo "VerifyObsBGEnsFmt = ${VerifyObsBGEnsFmt}"
#echo "VerifyObsANEnsFmt = ${VerifyObsANEnsFmt}"

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

#  set VerifyANInDirs = ($VerifyANInDirs ${VerificationWorkDir}/${anDir}${memDir}/${thisCycleDate}/${bgDir}
#  set VerifyBGInDirs = ($VerifyBGInDirs ${VerificationWorkDir}/${bgDir}${memDir}/${thisCycleDate}/${bgDir}
#  set VerifyEnsFCInDirs = ($VerifyEnsFCInDirs ${VerificationWorkDir}/${fcDir}${memDir}/${thisCycleDate}/${bgDir}
#
#  set VerifyANOutDirs = ($VerifyANOutDirs ${VerificationWorkDir}/${anDir}${memDir}/${thisCycleDate}/${anDir}
#  set VerifyBGOutDirs = ($VerifyBGOutDirs ${VerificationWorkDir}/${bgDir}${memDir}/${thisCycleDate}/${anDir}
#  set VerifyEnsFCOutDirs = ($VerifyEnsFCOutDirs ${VerificationWorkDir}/${fcDir}${memDir}/${thisCycleDate}/${anDir}

#  set VerifyFirstBGDirs = ($VerifyFirstBGDirs ${VerificationWorkDir}/${bgDir}${memDir}/${thisCycleDate})

  @ member++
end

#
# Universal time info for namelist, yaml etc:
# =============================================
set yy = `echo ${thisValidDate} | cut -c 1-4`
set mm = `echo ${thisValidDate} | cut -c 5-6`
set dd = `echo ${thisValidDate} | cut -c 7-8`
set hh = `echo ${thisValidDate} | cut -c 9-10`
set fileDate = ${yy}-${mm}-${dd}_${hh}.00.00
set NMLDate = ${yy}-${mm}-${dd}_${hh}:00:00
set ConfDate = ${yy}-${mm}-${dd}T${hh}:00:00Z

set localTemplateFieldsFile = ${TemplateFilePrefix}.$fileDate.nc
