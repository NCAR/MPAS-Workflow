#!/bin/csh -f

source config/experiment.csh

# job length and node/pe requirements
# ===================================

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
setenv VerifyObsNodes 1
setenv VerifyObsPEPerNode 36

setenv VerifyModelJobMinutes 2
setenv VerifyModelNodes 1
setenv VerifyModelPEPerNode 36

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

# EnsembleVariational
# not tested, too expensive
setenv EnsVariationalJobMinutes 1
setenv EnsVariationalMemory 45
setenv EnsVariationalPEPerNode 36
setenv EnsVariationalDANodes 1

setenv CyclingInflationJobMinutes 25
setenv CyclingInflationMemory 109
setenv CyclingInflationNodes ${HofXNodes}
setenv CyclingInflationPEPerNode ${HofXPEPerNode}
