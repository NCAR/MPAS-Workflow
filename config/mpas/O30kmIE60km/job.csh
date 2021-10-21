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
setenv VariationalMemory 45

# more efficient for basic experiment
#setenv VariationalNodesPerMember 6
#setenv VariationalPEPerNode 32
# Resource usage, single-state 3denvar, 20-member EnsB, 60 inner, CONV+AMSUA
# DATE       NODE-CONFIG  max memory (GB)  wall-time (s)
#                                          Total  fillGeoVaLs  fillGeoVaLsAD  fillGeoVaLsTL  Localization::multiply
# 2018041500 6-45GBx32PE  262.6            822    29.5         500            82.3           50.1
# 2018041506 6-45GBx32PE  258.5            762    30.4         459            71.5           47.1
# 2018041512 6-45GBx32PE  260.4            527    18.1         251            72.9           28.1
# 2018041518 6-45GBx32PE  260.6            797    31.8         453            81.4           48.8

# excess memory available for new experiments
setenv VariationalNodesPerMember 8
setenv VariationalPEPerNode 24
# Resource usage, single-state 3denvar, 20-member EnsB, 60 inner, CONV+AMSUA
# DATE       NODE-CONFIG  max memory (GB)  wall-time (s)
#                                          Total  fillGeoVaLs  fillGeoVaLsAD  fillGeoVaLsTL  Localization::multiply
# 2018041500 8-45GBx24PE  256.3            751    34.4         442            81.8           43.5
# 2018041506 8-45GBx24PE  254.6            581    19.6         279            111.           32.3
# 2018041512 8-45GBx24PE  262.2            775    27.5         456            81.9           44.7
# 2018041518 8-45GBx24PE  258.1            764    27.2         440            87.8           42.6
# TODO:
# Resource usage, single-state 3denvar, 80-member EnsB, 60 inner, CONV+AMSUA
# expect 30-40GB more memory is required for an 80-member EnsB based on OIE60km EDA-EnVar benchmarking
# DATE       NODE-CONFIG  max memory (GB)  wall-time (s)
#                                          Total  fillGeoVaLs  fillGeoVaLsAD  fillGeoVaLsTL  Localization::multiply
# 2018041500 8-45GBx24PE  ---.-            ---    --.-         ---            --.-           --.-
# 2018041506 8-45GBx24PE  ---.-            ---    --.-         ---            --.-           --.-
# 2018041512 8-45GBx24PE  ---.-            ---    --.-         ---            --.-           --.-
# 2018041518 8-45GBx24PE  ---.-            ---    --.-         ---            --.-           --.-

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
