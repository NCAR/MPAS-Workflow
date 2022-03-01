#!/bin/csh -f

source config/experiment.csh
source config/modeldata.csh

# job length and node/pe requirements
# ===================================

setenv InitICJobMinutes 1
setenv InitICNodes 1
setenv InitICPEPerNode 36

@ CyclingFCJobMinutes = 1 + ($CyclingWindowHR / 6)
setenv CyclingFCNodes 4
setenv CyclingFCPEPerNode 32

@ ExtendedFCJobMinutes = 1 + ($ExtendedFCWindowHR / 12)
setenv ExtendedFCNodes ${CyclingFCNodes}
setenv ExtendedFCPEPerNode ${CyclingFCPEPerNode}

# HofX
setenv HofXJobMinutes 5
setenv HofXNodes 1
setenv HofXPEPerNode 36
setenv HofXMemory 109

# ~8-12 min. for VerifyObsDA, ~5 min. for VerifyObsBG; 08OCT2021
set DeterministicVerifyObsJobMinutes = 15
set VerifyObsJobMinutes = ${DeterministicVerifyObsJobMinutes}

# ~180 sec. premium per 20 members for VerifyObsEnsMean; 08OCT2021
set EnsembleVerifyObsEnsMeanJobSecondsPerMember = 9
@ VerifyObsEnsMeanJobMinutes = ${nEnsDAMembers} * ${EnsembleVerifyObsEnsMeanJobSecondsPerMember} / 60
@ VerifyObsEnsMeanJobMinutes = ${VerifyObsEnsMeanJobMinutes} + ${DeterministicVerifyObsJobMinutes}

setenv VerifyModelJobMinutes 2

## Variational+EnsOfVariational
# benchmark: < 3 minutes
# longer duration with more observations
set DeterministicDABaseMinutes = 6 #develop
#set DeterministicDABaseMinutes = 30 #feature/getvals_upd

# Variational
if ( $nEnsDAMembers > 10 ) then
  # user fewer resources in large EDA jobs
  # nodes
  setenv VariationalMemory 109
  setenv VariationalNodesPerMember 1
  setenv VariationalPEPerNode 36

  # time per member (mostly localization multiplication, some IO)
  set ThreeDEnVarJobSecondsPerMember = 10
else
  # nodes
  setenv VariationalMemory 45
  setenv VariationalNodesPerMember 4
  setenv VariationalPEPerNode 32

  # time per member (mostly localization multiplication, some IO)
  # 60 inner x 1 outer, CONV+AMSUA obs; 20OCT2021
  # XX-members: 2018041506 (short) - (2018041518 (long) on 128pe
  # 20-members: 185-215 sec.
  # 40-members: 247-279 sec.
  # 80-members: 342-391 sec.
  # 50-60 sec. premium per 20 members
  set ThreeDEnVarJobSecondsPerMember = 5
endif

setenv VariationalNodes ${VariationalNodesPerMember}
@ ThreeDEnVarJobMinutes = ${ensPbNMembers} * ${ThreeDEnVarJobSecondsPerMember} / 60
@ ThreeDEnVarJobMinutes = ${ThreeDEnVarJobMinutes} + ${DeterministicDABaseMinutes}
setenv VariationalJobMinutes ${ThreeDEnVarJobMinutes}


# EnsembleOfVariational
set EnsembleDAJobSecondsPerMember = 10
@ EnsOfVariationalJobMinutes = ${nEnsDAMembers} * ${EnsembleDAJobSecondsPerMember} / 60
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
  @ nEDASubGroups = ${EDASize} / 5
  setenv EnsOfVariationalPEPerNode 30

  # each group of size 5 gets 6 nodes
  set nNodesPerGroup = 6
else if ( $divisibleBy3 == True ) then
  @ nEDASubGroups = ${EDASize} / 3
  setenv EnsOfVariationalPEPerNode 27

  # each group of size 3 gets 4 nodes
  set nNodesPerGroup = 4
else if ( $divisibleBy2 == True ) then
  @ nEDASubGroups = ${EDASize} / 2
  setenv EnsOfVariationalPEPerNode 24

  # each group of size 2 gets 3 nodes
  set nNodesPerGroup = 3
else
  set nEDASubGroups = ${EDASize}
  setenv EnsOfVariationalPEPerNode 18

  # each group of size 1 gets 2 nodes
  set nNodesPerGroup = 2
endif
@ EnsOfVariationalNodes = $nNodesPerGroup * $nEDASubGroups
setenv EnsOfVariationalNodes $EnsOfVariationalNodes

# inflation, e.g., RTPP
setenv CyclingInflationJobMinutes 25
setenv CyclingInflationMemory 109
setenv CyclingInflationNodes ${HofXNodes}
setenv CyclingInflationPEPerNode ${HofXPEPerNode}


