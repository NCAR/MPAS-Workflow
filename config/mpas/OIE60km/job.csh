#!/bin/csh -f

source config/experiment.csh
source config/modeldata.csh

# job length and node/pe requirements
# ===================================

@ InitICJobMinutes = 1
setenv InitICNodes 1
setenv InitICPEPerNode 36

@ CyclingFCJobMinutes = 1 + (3 * $CyclingWindowHR / 6)
setenv CyclingFCNodes 4
setenv CyclingFCPEPerNode 36

@ ExtendedFCJobMinutes = 1 + (3 * $ExtendedFCWindowHR / 12)
setenv ExtendedFCNodes ${CyclingFCNodes}
setenv ExtendedFCPEPerNode ${CyclingFCPEPerNode}

# HofX
setenv HofXJobMinutes 5
setenv HofXNodes 1
setenv HofXPEPerNode 36
setenv HofXMemory 109

# ~?-? min. for VerifyObsDA, ~? min. for VerifyObsBG
set DeterministicVerifyObsJobMinutes = 15
set VerifyObsJobMinutes = ${DeterministicVerifyObsJobMinutes}

# ? min. premium per 20 members for VerifyObsEnsMean
set EnsembleVerifyObsEnsMeanJobSecondsPerMember = 9
@ VerifyObsEnsMeanJobMinutes = ${nEnsDAMembers} * ${EnsembleVerifyObsEnsMeanJobSecondsPerMember} / 60
@ VerifyObsEnsMeanJobMinutes = ${VerifyObsEnsMeanJobMinutes} + ${DeterministicVerifyObsJobMinutes}
setenv VerifyObsNodes 1
setenv VerifyObsPEPerNode 36

setenv VerifyModelJobMinutes 5
setenv VerifyModelNodes 1
setenv VerifyModelPEPerNode 36

## Variational+EnsOfVariational
# Timing and memory required for different PE counts
# 2018041500, 2 EnVar members, 60 inner x 1 outer, CONV+AMSUA
# available counts: 64, 72, 96, 128, 144, 192, 256, 288, 384
# 96pe: 7-7.5 min., 134 GB memory
# 128pe: 6.5-8 min., 150 GB memory
# 144pe: 8 min., 152 GB memory
# 192pe: 8-8.5 min., 178 GB memory
# 384pe: 8-8.5 min., 234 GB memory
# benchmark: < 9 minutes
# longer duration with more observations
set DeterministicDABaseMinutes = 13

# Variational
setenv VariationalMemory 45

# 72pe
#setenv VariationalNodesPerMember 2
#setenv VariationalPEPerNode 36

# 96pe
##setenv VariationalNodesPerMember 3
##setenv VariationalPEPerNode 32
setenv VariationalNodesPerMember 4
setenv VariationalPEPerNode 24

# time per member (mostly localization multiplication, some IO)
## 60 inner x 1 outer, CONV+AMSUA obs
## 2018041500, XX EnVar members, Variational (XX members)
## XX-members: fastest member - slowest member
## 3x32=96pe, 109GB per node
# 20-members: 506-517 sec., 132-144 GB memory, ~57 sec. for Localization::multiply
# 40-members: 604-626 sec., 151-155 GB memory, ~117 sec. for Localization::multiply
# 80-members: - sec., - GB memory, ~? sec. for Localization::multiply
# 105 sec. premium per 20 members
#set ThreeDEnVarJobSecondsPerMember = 6

# 128pe
#setenv VariationalNodesPerMember 4
#setenv VariationalPEPerNode 32

# 144pe
##setenv VariationalNodesPerMember 4
##setenv VariationalPEPerNode 36
#setenv VariationalNodesPerMember 6
#setenv VariationalPEPerNode 24
# time per member (mostly localization multiplication, some IO)
## 60 inner x 1 outer, CONV+AMSUA obs
## 2018041500, XX EnVar members, Variational (XX members)
## XX-members: fastest member - slowest member
## 4x36=144pe, 109GB per node
# 20-members: 478-512 sec., 158-167 GB memory, ~32 sec. for Localization::multiply
# 40-members: 558-606 sec., 170-180 GB memory, ~66 sec. for Localization::multiply
#set ThreeDEnVarJobSecondsPerMember = 5

## 6x24=144pe, 45GB per node
# 20-members: 477-554 sec., 159-163 GB memory, ~46 sec. for Localization::multiply
# 80-members: 678-DNF(>15min. 3 of 5) sec., 194-? GB memory, >=170 sec. for Localization::multiply
# 90 sec. premium per 20 members
#set ThreeDEnVarJobSecondsPerMember = 8

# 192pe - preferred for 80-member EnVar based on wall-time and memory benchmarking
setenv VariationalNodesPerMember 6
setenv VariationalPEPerNode 32
# time per member (mostly localization multiplication, some IO)
## 60 inner x 1 outer, CONV+AMSUA obs
## 2018041500, XX EnVar members, Variational (XX members)
## XX-members: fastest member - slowest member
## 6x32=192pe, 45GB per node
# 20-members: 502-522 sec., 184-186 GB memory, ~32 sec. for Localization::multiply
# 40-members: 576-583 sec., 191-200 GB memory, ~62 sec. for Localization::multiply
# 80-members: 819-890 sec., 218-221 GB memory, ~132-145 sec. for Localization::multiply
# 110 sec. premium per 20 members

# note: more memory needed for all-sky experiments due to hydrometeor increment variables,
# ~290GB for 20-member 3DEnVar.  Either increase memory or change Nodes and PE.
#setenv VariationalMemory 109

set ThreeDEnVarJobSecondsPerMember = 7

# 384pe
#setenv VariationalNodesPerMember 12
#setenv VariationalPEPerNode 32

setenv VariationalNodes ${VariationalNodesPerMember}

@ ThreeDEnVarJobMinutes = ${ensPbNMembers} * ${ThreeDEnVarJobSecondsPerMember} / 60
@ ThreeDEnVarJobMinutes = ${ThreeDEnVarJobMinutes} + ${DeterministicDABaseMinutes}
setenv VariationalJobMinutes ${ThreeDEnVarJobMinutes}

# EnsembleOfVariational
set EnsembleDAJobSecondsPerMember = 10
@ EnsOfVariationalJobMinutes = ${nEnsDAMembers} * ${EnsembleDAJobSecondsPerMember} / 60
@ EnsOfVariationalJobMinutes = ${EnsOfVariationalJobMinutes} + ${ThreeDEnVarJobMinutes}
setenv EnsOfVariationalMemory 45

# special configs that work when EDASize is divisible by 3 and each
# member uses 192 PE's total
# + reduces total cost and queue time, but might increase EDA member imbalance
# TODO: ideally, we would have an estimate of memory useage per member,
# then use it to calculate the optimal EnsOfVariationalNodes and
# EnsOfVariationalPEPerNode, and also match the total NPE that was used for localization
# and/or covariance generation.  It is possible that NPE used for SABER applications
# no longer needs to be the same as NPE used in Variational applications.

set divisibleBy3 = False
@ THREERemainder = ${EDASize} % 3
if ( $THREERemainder == 0 ) then
  set divisibleBy3 = True
endif

if ( $divisibleBy3 == True ) then
  @ nEDASubGroups = ${EDASize} / 3
  setenv EnsOfVariationalPEPerNode 36

  # each group of size 3 gets 16 nodes
  set nNodesPerGroup = 16
else
  set nEDASubGroups = ${EDASize}
  setenv EnsOfVariationalPEPerNode 32

  # each group of size 1 gets 6 nodes
  set nNodesPerGroup = 6
endif
@ EnsOfVariationalNodes = $nNodesPerGroup * $nEDASubGroups
setenv EnsOfVariationalNodes $EnsOfVariationalNodes

# inflation, e.g., RTPP
setenv CyclingInflationJobMinutes 25
setenv CyclingInflationMemory 109
setenv CyclingInflationNodes ${HofXNodes}
setenv CyclingInflationPEPerNode ${HofXPEPerNode}


