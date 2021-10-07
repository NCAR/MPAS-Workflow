#!/bin/csh -f

source config/experiment.csh
source config/modeldata.csh

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

# ~8 min. for VerifyObsDA, ~5 min. for VerifyObsBG
set DeterministicVerifyObsJobMinutes = 10
set VerifyObsJobMinutes = ${DeterministicVerifyObsJobMinutes}

# 3 min. premium per 20 members for VerifyObsEnsMean
set EnsembleVerifyObsEnsMeanMembersPerJobMinute = 7
@ VerifyObsEnsMeanJobMinutes = ${nEnsDAMembers} / ${EnsembleVerifyObsEnsMeanMembersPerJobMinute}
@ VerifyObsEnsMeanJobMinutes = ${VerifyObsEnsMeanJobMinutes} + ${DeterministicVerifyObsJobMinutes}
setenv VerifyObsNodes 1
setenv VerifyObsPEPerNode 36

setenv VerifyModelJobMinutes 2
setenv VerifyModelNodes 1
setenv VerifyModelPEPerNode 36


set DeterministicDABaseMinutes = 4
set ThreeDEnVarMembersPerJobMinute = 12
@ ThreeDEnVarJobMinutes = ${ensPbNMembers} / ${ThreeDEnVarMembersPerJobMinute}
@ ThreeDEnVarJobMinutes = ${ThreeDEnVarJobMinutes} + ${DeterministicDABaseMinutes}
set EnsembleDAMembersPerJobMinute = 6
@ CyclingDAJobMinutes = ${nEnsDAMembers} / ${EnsembleDAMembersPerJobMinute}
@ CyclingDAJobMinutes = ${CyclingDAJobMinutes} + ${ThreeDEnVarJobMinutes}
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

# special config that works when nEnsDAMembers is divisible by 5
# reduces overhead
# TODO: ideally, we would have an estimate of memory useage per member,
# then use it to calculate the optimal CyclingDANodes and
# CyclingDAPEPerNode, and also match the total NPE that was used for localization
# and/or covariance generation.  It is possible that NPE used for SABER applications
# no longer needs to be the same as NPE used in Variational applications.
if ( "$nEnsDAMembers" == 80 ) then
  setenv CyclingDAPEPerNode 30
  setenv CyclingDANodes 96
else if ( "$nEnsDAMembers" == 70 ) then
  setenv CyclingDAPEPerNode 30
  setenv CyclingDANodes 84
else if ( "$nEnsDAMembers" == 60 ) then
  setenv CyclingDAPEPerNode 30
  setenv CyclingDANodes 72
else if ( "$nEnsDAMembers" == 50 ) then
  setenv CyclingDAPEPerNode 30
  setenv CyclingDANodes 60
else if ( "$nEnsDAMembers" == 40 ) then
  setenv CyclingDAPEPerNode 30
  setenv CyclingDANodes 48
else if ( "$nEnsDAMembers" == 30 ) then
  setenv CyclingDAPEPerNode 30
  setenv CyclingDANodes 36
else if ( "$nEnsDAMembers" == 20 ) then
  setenv CyclingDAPEPerNode 30
  setenv CyclingDANodes 24
else if ( "$nEnsDAMembers" == 10 ) then
  setenv CyclingDAPEPerNode 30
  setenv CyclingDANodes 12
else if ( "$nEnsDAMembers" == 5 ) then
  setenv CyclingDAPEPerNode 30
  setenv CyclingDANodes 6
else
  @ CyclingDANodes = ${CyclingDANodesPerMember} * ${nEnsDAMembers}
  setenv CyclingDANodes ${CyclingDANodes}
endif
