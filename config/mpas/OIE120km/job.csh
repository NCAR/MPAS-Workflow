#!/bin/csh -f

source config/experiment.csh
source config/modeldata.csh

# job length and node/pe requirements
# ===================================

@ CyclingFCJobMinutes = 1 + ($CyclingWindowHR / 6)
setenv CyclingFCNodes 4
setenv CyclingFCPEPerNode 32

@ ExtendedFCJobMinutes = 1 + ($ExtendedFCWindowHR / 12)
setenv ExtendedFCNodes ${CyclingFCNodes}
setenv ExtendedFCPEPerNode ${CyclingFCPEPerNode}

# HofX
setenv HofXJobMinutes 10
setenv HofXNodes 1
setenv HofXPEPerNode 36
setenv HofXMemory 109

# ~8-12 min. for VerifyObsDA, ~5 min. for VerifyObsBG; 08OCT2021
set DeterministicVerifyObsJobMinutes = 15
set VerifyObsJobMinutes = ${DeterministicVerifyObsJobMinutes}

# 3 min. premium per 20 members for VerifyObsEnsMean; 08OCT2021
set EnsembleVerifyObsEnsMeanMembersPerJobMinute = 7
@ VerifyObsEnsMeanJobMinutes = ${nEnsDAMembers} / ${EnsembleVerifyObsEnsMeanMembersPerJobMinute}
@ VerifyObsEnsMeanJobMinutes = ${VerifyObsEnsMeanJobMinutes} + ${DeterministicVerifyObsJobMinutes}
setenv VerifyObsNodes 1
setenv VerifyObsPEPerNode 36

setenv VerifyModelJobMinutes 2
setenv VerifyModelNodes 1
setenv VerifyModelPEPerNode 36

# ~5 min. for ThreeDEnVar, 60 inner x 1 outer, 20 member EnsB, CONV obs; 08OCT2021
# ~6 min. for ThreeDEnVar, 30 inner x 2 outer, 20 member EnsB, CONV obs + ABI + AHI; 08OCT2021
set DeterministicDABaseMinutes = 6
set ThreeDEnVarMembersPerJobMinute = 12
@ ThreeDEnVarJobMinutes = ${ensPbNMembers} / ${ThreeDEnVarMembersPerJobMinute}
@ ThreeDEnVarJobMinutes = ${ThreeDEnVarJobMinutes} + ${DeterministicDABaseMinutes}

# Variational
setenv VariationalJobMinutes ${ThreeDEnVarJobMinutes}
if ( $nEnsDAMembers > 10 ) then
  # save some resources in large EDA jobs
  setenv VariationalMemory 109
  setenv VariationalNodesPerMember 1
  setenv VariationalPEPerNode 36
else
  setenv VariationalMemory 45
  setenv VariationalNodesPerMember 4
  setenv VariationalPEPerNode 32
endif
setenv VariationalNodes ${VariationalNodesPerMember}

# EnsembleVariational
set EnsembleDAMembersPerJobMinute = 6
@ EnsVariationalJobMinutes = ${nEnsDAMembers} / ${EnsembleDAMembersPerJobMinute}
@ EnsVariationalJobMinutes = ${EnsVariationalJobMinutes} + ${ThreeDEnVarJobMinutes}
setenv EnsVariationalMemory 45

# special configs that work when nEnsDAMembers is divisible by 5
# + reduces total cost and queue time, but might increase EDA member imbalance
# TODO: ideally, we would have an estimate of memory useage per member,
# then use it to calculate the optimal EnsVariationalNodes and
# EnsVariationalPEPerNode, and also match the total NPE that was used for localization
# and/or covariance generation.  It is possible that NPE used for SABER applications
# no longer needs to be the same as NPE used in Variational applications.
if ( "$nEnsDAMembers" == 80 ) then
  setenv EnsVariationalPEPerNode 30
  setenv EnsVariationalNodes 96
else if ( "$nEnsDAMembers" == 70 ) then
  setenv EnsVariationalPEPerNode 30
  setenv EnsVariationalNodes 84
else if ( "$nEnsDAMembers" == 60 ) then
  setenv EnsVariationalPEPerNode 30
  setenv EnsVariationalNodes 72
else if ( "$nEnsDAMembers" == 50 ) then
  setenv EnsVariationalPEPerNode 30
  setenv EnsVariationalNodes 60
else if ( "$nEnsDAMembers" == 40 ) then
  setenv EnsVariationalPEPerNode 30
  setenv EnsVariationalNodes 48
else if ( "$nEnsDAMembers" == 30 ) then
  setenv EnsVariationalPEPerNode 30
  setenv EnsVariationalNodes 36
else if ( "$nEnsDAMembers" == 20 ) then
  setenv EnsVariationalPEPerNode 30
  setenv EnsVariationalNodes 24
else if ( "$nEnsDAMembers" == 10 ) then
  setenv EnsVariationalPEPerNode 30
  setenv EnsVariationalNodes 12
else if ( "$nEnsDAMembers" == 5 ) then
  setenv EnsVariationalPEPerNode 30
  setenv EnsVariationalNodes 6
else
  setenv EnsVariationalPEPerNode 18
  setenv EnsVariationalNodesPerMember 2
  @ EnsVariationalNodes = ${EnsVariationalNodesPerMember} * ${nEnsDAMembers}
  setenv EnsVariationalNodes ${EnsVariationalNodes}
endif

# inflation, e.g., RTPP
setenv CyclingInflationJobMinutes 25
setenv CyclingInflationMemory 109
setenv CyclingInflationNodes ${HofXNodes}
setenv CyclingInflationPEPerNode ${HofXPEPerNode}


