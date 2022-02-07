#!/bin/csh -f

source config/experiment.csh
source config/modeldata.csh

# job length and node/pe requirements
# ===================================

setenv InitICJobMinutes 1
setenv InitICNodes 1
setenv InitICPEPerNode 36

setenv ObstoIODAJobMinutes 10
setenv ObstoIODANodes 1
setenv ObstoIODAPEPerNode 1
setenv ObstoIODAMemory 109

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
set EnsembleVerifyObsEnsMeanJobSecondsPerMember = 9
@ VerifyObsEnsMeanJobMinutes = ${nEnsDAMembers} * ${EnsembleVerifyObsEnsMeanJobSecondsPerMember} / 60
@ VerifyObsEnsMeanJobMinutes = ${VerifyObsEnsMeanJobMinutes} + ${DeterministicVerifyObsJobMinutes}
setenv VerifyObsNodes 1
setenv VerifyObsPEPerNode 36

setenv VerifyModelJobMinutes 20
setenv VerifyModelNodes 1
setenv VerifyModelPEPerNode 36

set DeterministicDABaseMinutes = 20
set ThreeDEnVarJobSecondsPerMember = 5
@ ThreeDEnVarJobMinutes = ${ensPbNMembers} * ${ThreeDEnVarJobSecondsPerMember} / 60
@ ThreeDEnVarJobMinutes = ${ThreeDEnVarJobMinutes} + ${DeterministicDABaseMinutes}

# Variational
setenv VariationalJobMinutes ${ThreeDEnVarJobMinutes}
setenv VariationalMemory 109
setenv VariationalNodesPerMember 4
setenv VariationalPEPerNode 32
setenv VariationalNodes ${VariationalNodesPerMember}

# EnsembleOfVariational
# not tested, likely infeasible
set EnsembleDAJobSecondsPerMember = 10
@ EnsOfVariationalJobMinutes = ${nEnsDAMembers} * ${EnsembleDAJobSecondsPerMember} / 60
@ EnsOfVariationalJobMinutes = ${EnsOfVariationalJobMinutes} + ${ThreeDEnVarJobMinutes}
setenv EnsOfVariationalMemory 109
setenv EnsOfVariationalNodesPerMember 3
setenv EnsOfVariationalPEPerNode      12
@ EnsOfVariationalNodes = ${EnsOfVariationalNodesPerMember} * ${EDASize}
setenv EnsOfVariationalNodes ${EnsOfVariationalNodes}

# inflation, e.g., RTPP
setenv CyclingInflationJobMinutes 25
setenv CyclingInflationMemory 109
setenv CyclingInflationNodes ${HofXNodes}
setenv CyclingInflationPEPerNode ${HofXPEPerNode}
