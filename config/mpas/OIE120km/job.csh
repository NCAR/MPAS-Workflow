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

# EnsembleOfVariational
set EnsembleDAMembersPerJobMinute = 6
@ EnsOfVariationalJobMinutes = ${nEnsDAMembers} / ${EnsembleDAMembersPerJobMinute}
@ EnsOfVariationalJobMinutes = ${EnsOfVariationalJobMinutes} + ${ThreeDEnVarJobMinutes}
setenv EnsOfVariationalMemory 45

# special configs that work when nEnsDAMembers is divisible by 5
# + reduces total cost and queue time, but might increase EDA member imbalance
# TODO: ideally, we would have an estimate of memory useage per member,
# then use it to calculate the optimal EnsOfVariationalNodes and
# EnsOfVariationalPEPerNode, and also match the total NPE that was used for localization
# and/or covariance generation.  It is possible that NPE used for SABER applications
# no longer needs to be the same as NPE used in Variational applications.
if ( "$nEnsDAMembers" == 80 ) then
  setenv EnsOfVariationalPEPerNode 30
  setenv EnsOfVariationalNodes 96
else if ( "$nEnsDAMembers" == 70 ) then
  setenv EnsOfVariationalPEPerNode 30
  setenv EnsOfVariationalNodes 84
else if ( "$nEnsDAMembers" == 60 ) then
  setenv EnsOfVariationalPEPerNode 30
  setenv EnsOfVariationalNodes 72
else if ( "$nEnsDAMembers" == 50 ) then
  setenv EnsOfVariationalPEPerNode 30
  setenv EnsOfVariationalNodes 60
else if ( "$nEnsDAMembers" == 40 ) then
  setenv EnsOfVariationalPEPerNode 30
  setenv EnsOfVariationalNodes 48
else if ( "$nEnsDAMembers" == 30 ) then
  setenv EnsOfVariationalPEPerNode 30
  setenv EnsOfVariationalNodes 36
else if ( "$nEnsDAMembers" == 20 ) then
  setenv EnsOfVariationalPEPerNode 30
  setenv EnsOfVariationalNodes 24
else if ( "$nEnsDAMembers" == 10 ) then
  setenv EnsOfVariationalPEPerNode 30
  setenv EnsOfVariationalNodes 12
else if ( "$nEnsDAMembers" == 5 ) then
  setenv EnsOfVariationalPEPerNode 30
  setenv EnsOfVariationalNodes 6
else
  setenv EnsOfVariationalPEPerNode 18
  setenv EnsOfVariationalNodesPerMember 2
  @ EnsOfVariationalNodes = ${EnsOfVariationalNodesPerMember} * ${nEnsDAMembers}
  setenv EnsOfVariationalNodes ${EnsOfVariationalNodes}
endif

# inflation, e.g., RTPP
setenv CyclingInflationJobMinutes 25
setenv CyclingInflationMemory 109
setenv CyclingInflationNodes ${HofXNodes}
setenv CyclingInflationPEPerNode ${HofXPEPerNode}


