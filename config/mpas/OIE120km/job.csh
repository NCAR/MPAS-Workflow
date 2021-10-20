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

# special configs that work when EDASize is divisible by 5, 3, or 2 and each
# member uses 36 PE's total
# + reduces total cost and queue time, but might increase EDA member imbalance
# TODO: ideally, we would have an estimate of memory useage per member,
# then use it to calculate the optimal EnsOfVariationalNodes and
# EnsOfVariationalPEPerNode, and also match the total NPE that was used for localization
# and/or covariance generation.  It is possible that NPE used for SABER applications
# no longer needs to be the same as NPE used in Variational applications.

set divisibleBy5 = False
@ FIVERemainder = ${EDASize} % 5
if ( $FIVERemainder == 0 ) then
  set divisibleBy5 = True
endif
set divisibleBy3 = False
@ THREERemainder = ${EDASize} % 3
if ( $THREERemainder == 0 ) then
  set divisibleBy3 = True
endif
set divisibleBy2 = False
@ TWORemainder = ${EDASize} % 2
if ( $TWORemainder == 0 ) then
  set divisibleBy2 = True
endif

if ( $divisibleBy5 == True ) then
  @ nGroups = ${EDASize} / 5
  setenv EnsOfVariationalPEPerNode 30
  set nNodesPerGroup = 6
else if ( $divisibleBy3 == True ) then
  @ nGroups = ${EDASize} / 3
  setenv EnsOfVariationalPEPerNode 27
  set nNodesPerGroup = 4
else if ( $divisibleBy2 == True ) then
  @ nGroups = ${EDASize} / 2
  setenv EnsOfVariationalPEPerNode 24
  set nNodesPerGroup = 3
else
  set nGroups = ${EDASize}
  setenv EnsOfVariationalPEPerNode 18
  set nNodesPerGroup = 2
endif
@ EnsOfVariationalNodes = $nNodesPerGroup * $nGroups
setenv EnsOfVariationalNodes $EnsOfVariationalNodes

# inflation, e.g., RTPP
setenv CyclingInflationJobMinutes 25
setenv CyclingInflationMemory 109
setenv CyclingInflationNodes ${HofXNodes}
setenv CyclingInflationPEPerNode ${HofXPEPerNode}


