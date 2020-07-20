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
set VerifyFirstBGDirs = ()
set VerifyFCDirs = ()

set member = 1
while ( $member <= ${nEnsDAMembers} )
  set memDir = `${memberDir} $DAType $member`
  set CyclingDAInDirs = ($CyclingDAInDirs ${CyclingDAInDir}${memDir})
  set CyclingDAOutDirs = ($CyclingDAOutDirs ${CyclingDAOutDir}${memDir})
  set CyclingFCDirs = ($CyclingFCDirs ${CyclingFCDir}${memDir})
  set prevCyclingFCDirs = ($prevCyclingFCDirs ${prevCyclingFCDir}${memDir})
  set ExtendedFCDirs = ($ExtendedFCDirs ${ExtendedFCDir}${memDir})
  set VerifyANDirs = ($VerifyANDirs ${VerificationWorkDir}/${anDir}${memDir}/${cycle_Date})
  set VerifyBGDirs = ($VerifyBGDirs ${VerificationWorkDir}/${bgDir}${memDir}/${nextDate})
  set VerifyFirstBGDirs = ($VerifyFirstBGDirs ${VerificationWorkDir}/${bgDir}${memDir}/${cycle_Date})
  set VerifyFCDirs = ($VerifyFCDirs ${VerificationWorkDir}/${fcDir}${memDir}/${cycle_Date})
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

