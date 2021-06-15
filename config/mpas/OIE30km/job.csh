#!/bin/csh -f

source config/experiment.csh

## job length and node/pe requirements

# Uniform 30km mesh
# -----------------
@ CyclingFCJobMinutes = 5 + (5 * $CyclingWindowHR / 6)
setenv CyclingFCNodes 8
setenv CyclingFCPEPerNode 32

@ ExtendedFCJobMinutes = 1 + ($ExtendedFCWindowHR / 4)
setenv ExtendedFCNodes ${CyclingFCNodes}
setenv ExtendedFCPEPerNode ${CyclingFCPEPerNode}

setenv HofXJobMinutes 10
setenv HofXNodes 32
setenv HofXPEPerNode 16
setenv HofXMemory 109

set DeterministicVerifyObsJobMinutes = 5
set VerifyObsJobMinutes = ${DeterministicVerifyObsJobMinutes}
set EnsembleVerifyObsEnsMeanMembersPerJobMinute = 10
@ VerifyObsEnsMeanJobMinutes = ${nEnsDAMembers} / ${EnsembleVerifyObsEnsMeanMembersPerJobMinute}
@ VerifyObsEnsMeanJobMinutes = ${VerifyObsEnsMeanJobMinutes} + ${DeterministicVerifyObsJobMinutes}
setenv VerifyObsNodes 1
setenv VerifyObsPEPerNode 36

setenv VerifyModelJobMinutes 2
setenv VerifyModelNodes 1
setenv VerifyModelPEPerNode 36

set DeterministicDAJobMinutes = 25
set EnsembleDAMembersPerJobMinute = 2
@ CyclingDAJobMinutes = ${nEnsDAMembers} / ${EnsembleDAMembersPerJobMinute}
@ CyclingDAJobMinutes = ${CyclingDAJobMinutes} + ${DeterministicDAJobMinutes}
setenv CyclingDAMemory 109
if ( "$DAType" =~ *"eda"* ) then
  setenv CyclingDANodesPerMember 64
  setenv CyclingDAPEPerNode 8
else
  setenv CyclingDANodesPerMember 64
  setenv CyclingDAPEPerNode 8
endif

setenv CyclingInflationJobMinutes 25
setenv CyclingInflationMemory 109
setenv CyclingInflationNodesPerMember ${HofXNodes}
setenv CyclingInflationPEPerNode      ${HofXPEPerNode}

@ CyclingDAPEPerMember = ${CyclingDANodesPerMember} * ${CyclingDAPEPerNode}
setenv CyclingDAPEPerMember ${CyclingDAPEPerMember}

@ CyclingDANodes = ${CyclingDANodesPerMember} * ${nEnsDAMembers}
setenv CyclingDANodes ${CyclingDANodes}
