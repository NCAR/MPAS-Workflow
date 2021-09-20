#!/bin/csh -f

source config/experiment.csh

## job length and node/pe requirements

# Uniform 120km mesh
# ------------------
@ CyclingFCJobMinutes = 1 + ($CyclingWindowHR / 6)
setenv CyclingFCNodes 4
setenv CyclingFCPEPerNode 32

@ ExtendedFCJobMinutes = 1 + ($ExtendedFCWindowHR / 12)
setenv ExtendedFCNodes ${CyclingFCNodes}
setenv ExtendedFCPEPerNode ${CyclingFCPEPerNode}

setenv HofXJobMinutes 10
setenv HofXNodes 1
setenv HofXPEPerNode 36
setenv HofXMemory 109

set DeterministicVerifyObsJobMinutes = 15
set VerifyObsJobMinutes = ${DeterministicVerifyObsJobMinutes}
set EnsembleVerifyObsEnsMeanMembersPerJobMinute = 10
@ VerifyObsEnsMeanJobMinutes = ${nEnsDAMembers} / ${EnsembleVerifyObsEnsMeanMembersPerJobMinute}
@ VerifyObsEnsMeanJobMinutes = ${VerifyObsEnsMeanJobMinutes} + ${DeterministicVerifyObsJobMinutes}
setenv VerifyObsNodes 1
setenv VerifyObsPEPerNode 36

setenv VerifyModelJobMinutes 2
setenv VerifyModelNodes 1
setenv VerifyModelPEPerNode 36


set DeterministicDAJobMinutes = 5
set EnsembleDAMembersPerJobMinute = 3
@ CyclingDAJobMinutes = ${nEnsDAMembers} / ${EnsembleDAMembersPerJobMinute}
@ CyclingDAJobMinutes = ${CyclingDAJobMinutes} + ${DeterministicDAJobMinutes}
setenv CyclingDAMemory 45
#setenv CyclingDAMemory 109
if ( "$DAType" =~ *"eda"* ) then
  setenv CyclingDANodesPerMember 2
  setenv CyclingDAPEPerNode      18
else
  setenv CyclingDANodesPerMember 4
  setenv CyclingDAPEPerNode      32
endif

setenv CyclingInflationJobMinutes 25
setenv CyclingInflationMemory 109
setenv CyclingInflationNodes ${HofXNodes}
setenv CyclingInflationPEPerNode ${HofXPEPerNode}

if ( "$nEnsDAMembers" == 80 ) then
  # special config that works for 80 members and reduces overhead
  # ideally, there would be an estimate of memory useage per member,
  # which could be used to calculate the optimal CyclingDANodes and
  # CyclingDAPEPerNode that match the NPE used for localization and
  # covariance generation (latter may become generic)
  setenv CyclingDAPEPerNode 30
  setenv CyclingDANodes 96
else
  @ CyclingDANodes = ${CyclingDANodesPerMember} * ${nEnsDAMembers}
  setenv CyclingDANodes ${CyclingDANodes}
endif
