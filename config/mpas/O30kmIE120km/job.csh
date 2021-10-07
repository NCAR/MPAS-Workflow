#!/bin/csh -f

source config/experiment.csh

## job length and node/pe requirements

# Uniform 30km mesh -- forecast, hofx, variational outer loop
# Uniform 120km mesh -- variational inner loop

@ CyclingFCJobMinutes = 2 + (7 * $CyclingWindowHR / 6)
setenv CyclingFCNodes 16
setenv CyclingFCPEPerNode 32

@ ExtendedFCJobMinutes = 1 + ($ExtendedFCWindowHR / 4)
setenv ExtendedFCNodes ${CyclingFCNodes}
setenv ExtendedFCPEPerNode ${CyclingFCPEPerNode}

# bump interpolation
#setenv HofXJobMinutes 20
#setenv HofXNodes 4

# unstructured interpolation
setenv HofXJobMinutes 10
setenv HofXNodes 2

setenv HofXPEPerNode 36
setenv HofXMemory 109

set DeterministicVerifyObsJobMinutes = 5
set VerifyObsJobMinutes = ${DeterministicVerifyObsJobMinutes}
set EnsembleVerifyObsEnsMeanMembersPerJobMinute = 10
@ VerifyObsEnsMeanJobMinutes = ${nEnsDAMembers} / ${EnsembleVerifyObsEnsMeanMembersPerJobMinute}
@ VerifyObsEnsMeanJobMinutes = ${VerifyObsEnsMeanJobMinutes} + ${DeterministicVerifyObsJobMinutes}
setenv VerifyObsNodes 1
setenv VerifyObsPEPerNode 36

setenv VerifyModelJobMinutes 20
setenv VerifyModelNodes 1
setenv VerifyModelPEPerNode 36


set DeterministicDAJobMinutes = 20
set EnsembleDAMembersPerJobMinute = 5
@ CyclingDAJobMinutes = ${nEnsDAMembers} / ${EnsembleDAMembersPerJobMinute}
@ CyclingDAJobMinutes = ${CyclingDAJobMinutes} + ${DeterministicDAJobMinutes}
#setenv CyclingDAMemory 45
setenv CyclingDAMemory 109
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

@ CyclingDANodes = ${CyclingDANodesPerMember} * ${nEnsDAMembers}
setenv CyclingDANodes ${CyclingDANodes}
