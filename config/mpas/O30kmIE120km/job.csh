#!/bin/csh -f

source config/experiment.csh
source config/modeldata.csh

# job length and node/pe requirements
# ===================================

@ CyclingFCJobMinutes = 2 + (7 * $CyclingWindowHR / 6)
setenv CyclingFCNodes 16
setenv CyclingFCPEPerNode 32

@ ExtendedFCJobMinutes = 1 + ($ExtendedFCWindowHR / 4)
setenv ExtendedFCNodes ${CyclingFCNodes}
setenv ExtendedFCPEPerNode ${CyclingFCPEPerNode}

## HofX
# bump interpolation
#setenv HofXJobMinutes 20
#setenv HofXNodes 4

# unstructured interpolation
setenv HofXJobMinutes 10
setenv HofXNodes 2

setenv HofXPEPerNode 36
setenv HofXMemory 109

# ~8-12 min. for VerifyObsDA, ~5 min. for VerifyObsBG
set DeterministicVerifyObsJobMinutes = 15
set VerifyObsJobMinutes = ${DeterministicVerifyObsJobMinutes}

# 3 min. premium per 20 members for VerifyObsEnsMean
set EnsembleVerifyObsEnsMeanMembersPerJobMinute = 7
@ VerifyObsEnsMeanJobMinutes = ${nEnsDAMembers} / ${EnsembleVerifyObsEnsMeanMembersPerJobMinute}
@ VerifyObsEnsMeanJobMinutes = ${VerifyObsEnsMeanJobMinutes} + ${DeterministicVerifyObsJobMinutes}
setenv VerifyObsNodes 1
setenv VerifyObsPEPerNode 36

setenv VerifyModelJobMinutes 20
setenv VerifyModelNodes 1
setenv VerifyModelPEPerNode 36

set DeterministicDABaseMinutes = 20
set ThreeDEnVarMembersPerJobMinute = 12
@ ThreeDEnVarJobMinutes = ${ensPbNMembers} / ${ThreeDEnVarMembersPerJobMinute}
@ ThreeDEnVarJobMinutes = ${ThreeDEnVarJobMinutes} + ${DeterministicDABaseMinutes}

# Variational
setenv VariationalJobMinutes ${ThreeDEnVarJobMinutes}
setenv VariationalMemory 109
setenv VariationalNodesPerMember 4
setenv VariationalPEPerNode 32
setenv VariationalNodes ${VariationalNodesPerMember}

# EnsembleOfVariational
# not tested, likely infeasible
set EnsembleDAMembersPerJobMinute = 6
@ EnsOfVariationalJobMinutes = ${nEnsDAMembers} / ${EnsembleDAMembersPerJobMinute}
@ EnsOfVariationalJobMinutes = ${EnsOfVariationalJobMinutes} + ${ThreeDEnVarJobMinutes}
setenv EnsOfVariationalMemory 109
setenv EnsOfVariationalNodesPerMember 3
setenv EnsOfVariationalPEPerNode      12
@ EnsOfVariationalNodes = ${EnsOfVariationalNodesPerMember} * ${nEnsDAMembers}
setenv EnsOfVariationalNodes ${EnsOfVariationalNodes}

# inflation, e.g., RTPP
setenv CyclingInflationJobMinutes 25
setenv CyclingInflationMemory 109
setenv CyclingInflationNodes ${HofXNodes}
setenv CyclingInflationPEPerNode ${HofXPEPerNode}
