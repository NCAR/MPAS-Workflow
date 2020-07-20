#!/bin/csh -f
set prevCycleDate = `$advanceCYMDH ${thisCycleDate} -${CYWindowHR}`
#set nextCycleDate = `$advanceCYMDH ${thisCycleDate} ${CYWindowHR}`
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

set CyclingDAInDirs = ()
set CyclingDAOutDirs = ()
set CyclingFCDirs = ()
set prevCyclingFCDirs = ()
set ExtendedFCDirs = ()

set VerifyBGDirs = ()
set VerifyANDirs = ()
set VerifyFCDirs = ()
#set VerifyBGInDirs = ()
#set VerifyANInDirs = ()
#set VerifyFCInDirs = ()
#set VerifyBGOutDirs = ()
#set VerifyANOutDirs = ()
#set VerifyFCOutDirs = ()

#set VerifyFirstBGDirs = ()

set member = 1
while ( $member <= ${nEnsDAMembers} )
  set memDir = `${memberDir} $DAType $member`
  set CyclingDAInDirs = ($CyclingDAInDirs ${CyclingDAInDir}${memDir})
  set CyclingDAOutDirs = ($CyclingDAOutDirs ${CyclingDAOutDir}${memDir})
  set CyclingFCDirs = ($CyclingFCDirs ${CyclingFCDir}${memDir})
  set prevCyclingFCDirs = ($prevCyclingFCDirs ${prevCyclingFCDir}${memDir})
  set ExtendedFCDirs = ($ExtendedFCDirs ${ExtendedFCDir}${memDir})
  set VerifyANDirs = ($VerifyANDirs ${VerificationWorkDir}/${anDir}${memDir}/${thisCycleDate})
  set VerifyBGDirs = ($VerifyBGDirs ${VerificationWorkDir}/${bgDir}${memDir}/${thisCycleDate})
  set VerifyFCDirs = ($VerifyFCDirs ${VerificationWorkDir}/${fcDir}${memDir}/${thisCycleDate})

#  set VerifyANInDirs = ($VerifyANInDirs ${VerificationWorkDir}/${anDir}${memDir}/${thisCycleDate}/${bgDir}
#  set VerifyBGInDirs = ($VerifyBGInDirs ${VerificationWorkDir}/${bgDir}${memDir}/${thisCycleDate}/${bgDir}
#  set VerifyFCInDirs = ($VerifyFCInDirs ${VerificationWorkDir}/${fcDir}${memDir}/${thisCycleDate}/${bgDir}
#
#  set VerifyANOutDirs = ($VerifyANOutDirs ${VerificationWorkDir}/${anDir}${memDir}/${thisCycleDate}/${anDir}
#  set VerifyBGOutDirs = ($VerifyBGOutDirs ${VerificationWorkDir}/${bgDir}${memDir}/${thisCycleDate}/${anDir}
#  set VerifyFCOutDirs = ($VerifyFCOutDirs ${VerificationWorkDir}/${fcDir}${memDir}/${thisCycleDate}/${anDir}

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
