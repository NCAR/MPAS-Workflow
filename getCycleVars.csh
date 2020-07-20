#!/bin/csh -f
set prevDate = `$advanceCYMDH ${cycle_Date} -${CYWindowHR}`
set nextDate = `$advanceCYMDH ${cycle_Date} ${CYWindowHR}`
setenv prevDate ${prevDate}
setenv nextDate ${nextDate}

## setup cycle directory names
set CyclingDADir = ${CyclingDAWorkDir}/${cycle_Date}
set CyclingDAInDir = ${CyclingDADir}/${bgDir}
set CyclingDAOutDir = ${CyclingDADir}/${anDir}

set prevCyclingDADir = ${CyclingDAWorkDir}/${prevDate}
set CyclingFCDir = ${CyclingFCWorkDir}/${cycle_Date}
set prevCyclingFCDir = ${CyclingFCWorkDir}/${prevDate}
set ExtendedFCDir = ${ExtendedFCWorkDir}/${cycle_Date}

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
  set VerifyANDirs = ($VerifyANDirs ${VerificationWorkDir}/${anDir}${memDir}/${cycle_Date})
  set VerifyBGDirs = ($VerifyBGDirs ${VerificationWorkDir}/${bgDir}${memDir}/${cycle_Date})
  set VerifyFCDirs = ($VerifyFCDirs ${VerificationWorkDir}/${fcDir}${memDir}/${cycle_Date})

#  set VerifyANInDirs = ($VerifyANInDirs ${VerificationWorkDir}/${anDir}${memDir}/${cycle_Date}/${bgDir}
#  set VerifyBGInDirs = ($VerifyBGInDirs ${VerificationWorkDir}/${bgDir}${memDir}/${cycle_Date}/${bgDir}
#  set VerifyFCInDirs = ($VerifyFCInDirs ${VerificationWorkDir}/${fcDir}${memDir}/${cycle_Date}/${bgDir}
#
#  set VerifyANOutDirs = ($VerifyANOutDirs ${VerificationWorkDir}/${anDir}${memDir}/${cycle_Date}/${anDir}
#  set VerifyBGOutDirs = ($VerifyBGOutDirs ${VerificationWorkDir}/${bgDir}${memDir}/${cycle_Date}/${anDir}
#  set VerifyFCOutDirs = ($VerifyFCOutDirs ${VerificationWorkDir}/${fcDir}${memDir}/${cycle_Date}/${anDir}

#  set VerifyFirstBGDirs = ($VerifyFirstBGDirs ${VerificationWorkDir}/${bgDir}${memDir}/${cycle_Date})

  @ member++
end

set VerifyFCDirsStepsMembers = ()

#@ dt = 0
#set step = 1
#while ( $dt <= ${ExtendedFCWindowHR} )
#  set member = 1
#  @ index = ($step * ${nEnsDAMembers}) + $member
#  while ( $member <= ${nEnsDAMembers} )
#    set VerifyFCDirsStepsMembers = ($VerifyFCDirsStepsMembers )
#    @ member++
#  end
#  @ step++
#end


#
# Time info for namelist, yaml etc:
# =============================================
set yy = `echo ${validDate} | cut -c 1-4`
set mm = `echo ${validDate} | cut -c 5-6`
set dd = `echo ${validDate} | cut -c 7-8`
set hh = `echo ${validDate} | cut -c 9-10`
set fileDate = ${yy}-${mm}-${dd}_${hh}.00.00
set NMLDate = ${yy}-${mm}-${dd}_${hh}:00:00
set ConfDate = ${yy}-${mm}-${dd}T${hh}:00:00Z
