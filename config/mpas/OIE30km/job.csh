#!/bin/csh -f

source config/experiment.csh

# job length and node/pe requirements
# ===================================

setenv InitICJobMinutes 1
setenv InitICNodes 1
setenv InitICPEPerNode 36

@ CyclingFCJobMinutes = 5 + (5 * $CyclingWindowHR / 6)
setenv CyclingFCNodes 8
setenv CyclingFCPEPerNode 32

@ ExtendedFCJobMinutes = 1 + ($ExtendedFCWindowHR / 4)
setenv ExtendedFCNodes ${CyclingFCNodes}
setenv ExtendedFCPEPerNode ${CyclingFCPEPerNode}

# HofX
setenv HofXJobMinutes 10
setenv HofXNodes 32
setenv HofXPEPerNode 16
setenv HofXMemory 109

set DeterministicVerifyObsJobMinutes = 5
set VerifyObsJobMinutes = ${DeterministicVerifyObsJobMinutes}
set EnsembleVerifyObsEnsMeanMembersPerJobMinute = 10
@ VerifyObsEnsMeanJobMinutes = ${nEnsDAMembers} / ${EnsembleVerifyObsEnsMeanMembersPerJobMinute}
@ VerifyObsEnsMeanJobMinutes = ${VerifyObsEnsMeanJobMinutes} + ${DeterministicVerifyObsJobMinutes}

setenv VerifyModelJobMinutes 2

set DeterministicDABaseMinutes = 25
set ThreeDEnVarMembersPerJobMinute = 12
@ ThreeDEnVarJobMinutes = ${ensPbNMembers} / ${ThreeDEnVarMembersPerJobMinute}
@ ThreeDEnVarJobMinutes = ${ThreeDEnVarJobMinutes} + ${DeterministicDABaseMinutes}

# Variational
setenv VariationalJobMinutes ${ThreeDEnVarJobMinutes}
setenv VariationalMemory 109
setenv VariationalNodesPerMember 64
setenv VariationalPEPerNode 8
setenv VariationalNodes ${VariationalNodesPerMember}

# EnsembleOfVariational
# not tested, too expensive
setenv EnsOfVariationalJobMinutes 1
setenv EnsOfVariationalMemory 45
setenv EnsOfVariationalPEPerNode 36
setenv EnsOfVariationalDANodes 1

setenv CyclingInflationJobMinutes 25
setenv CyclingInflationMemory 109
setenv CyclingInflationNodes ${HofXNodes}
setenv CyclingInflationPEPerNode ${HofXPEPerNode}
