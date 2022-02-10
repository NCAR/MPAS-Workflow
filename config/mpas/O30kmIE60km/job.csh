#!/bin/csh -f

source config/experiment.csh
source config/modeldata.csh

# job length and node/pe requirements
# ===================================

@ InitICJobMinutes = 1
setenv InitICNodes 1
setenv InitICPEPerNode 36

@ CyclingFCJobMinutes = 1 + (8 * $CyclingWindowHR / 6)
setenv CyclingFCNodes 16
setenv CyclingFCPEPerNode 32

@ ExtendedFCJobMinutes = 1 + (6 * $ExtendedFCWindowHR / 6)
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
set DeterministicVerifyObsJobMinutes = 25
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

# benchmark: < 20 minutes
# longer duration with more observations
set DeterministicDABaseMinutes = 40

# wall-time increase per member in ensemble B
# TODO: run tests w/ > 20 members
set ThreeDEnVarJobSecondsPerMember = 7
@ ThreeDEnVarJobMinutes = ${ensPbNMembers} * ${ThreeDEnVarJobSecondsPerMember} / 60
@ ThreeDEnVarJobMinutes = ${ThreeDEnVarJobMinutes} + ${DeterministicDABaseMinutes}

# Variational
setenv VariationalJobMinutes ${ThreeDEnVarJobMinutes}

# most efficient and lower queue times for basic experiments
#setenv VariationalNodesPerMember 6
#setenv VariationalPEPerNode 32
#setenv VariationalMemory 45
# Resource usage, single-state 3denvar, 20-member EnsB, 60 inner, CONV+AMSUA, OCT5 code
# DATE       NODE-CONFIG  max memory (GB)  wall-time (s)
#                                          Total  fillGeoVaLs  fillGeoVaLsAD  fillGeoVaLsTL  Localization::multiply
# 2018041500 6-45GBx32PE  262.6            822    29.5         500            82.3           50.1
# 2018041506 6-45GBx32PE  258.5            762    30.4         459            71.5           47.1
# 2018041512 6-45GBx32PE  260.4            527    18.1         251            72.9           28.1
# 2018041518 6-45GBx32PE  260.6            797    31.8         453            81.4           48.8

# sometimes need excess memory for non-basic experiments
#setenv VariationalNodesPerMember 8
#setenv VariationalPEPerNode 24
#setenv VariationalMemory 45
# Resource usage, single-state 3denvar, 20-member EnsB, 60 inner, CONV+AMSUA, OCT5 code
# DATE       NODE-CONFIG  max memory (GB)  wall-time (s)
#                                          Total  fillGeoVaLs  fillGeoVaLsAD  fillGeoVaLsTL  Localization::multiply
# 2018041500 8-45GBx24PE  256.3            751    34.4         442            81.8           43.5
# 2018041506 8-45GBx24PE  254.6            581    19.6         279            111.           32.3
# 2018041512 8-45GBx24PE  262.2            775    27.5         456            81.9           44.7
# 2018041518 8-45GBx24PE  258.1            764    27.2         440            87.8           42.6

# even more memory is needed when assimilating ABI and AHI
# Most likely cause for extra wall-time (fillGeoVaLs* communications) and memory (increment copies in minimization) are the
# five extra 3d hydrometeor fields in the increment: qc, qi, qg, qr, qs
#setenv VariationalNodesPerMember 12
#setenv VariationalPEPerNode 16
#setenv VariationalMemory 45
# Resource usage, single-state 3denvar, 20-member EnsB, 60 inner, CONV+AMSUA+ABI(100km-thin)+AHI(100km-thin), OCT22 code
# DATE       NODE-CONFIG  max memory (GB)  wall-time (s)
#                                          Total  fillGeoVaLs  fillGeoVaLsAD  fillGeoVaLsTL  Localization::multiply
# 2018041500 12-45GBx16PE 369.2            1041   57.9         562            112.6          68.4
# 2018041506 12-45GBx16PE 371.4            1042   56.0         561            121.1          73.0

# big-memory nodes significantly reduce wall-time (20%), and total core-hour cost by 60%
setenv VariationalNodesPerMember 6
setenv VariationalPEPerNode 32
setenv VariationalMemory 109
# Resource usage, single-state 3denvar, 20-member EnsB, 60 inner, CONV+AMSUA+ABI(100km-thin)+AHI(100km-thin), OCT22 code
# DATE       NODE-CONFIG  max memory (GB)  wall-time (s)
#                                          Total  fillGeoVaLs  fillGeoVaLsAD  fillGeoVaLsTL  Localization::multiply
# 2018041500 6-109GBX32PE 370.3            805    32.8         392            112.8          46.4
# 2018041506 6-109GBX32PE 372.4            837    35.2         404            124.5          46.7

# TODO:
# Resource usage, single-state 3denvar, 80-member EnsB, 60 inner, CONV+AMSUA
# expect 30-40GB more memory is required for an 80-member EnsB based on OIE60km EDA-EnVar benchmarking
# DATE       NODE-CONFIG  max memory (GB)  wall-time (s)
#                                          Total  fillGeoVaLs  fillGeoVaLsAD  fillGeoVaLsTL  Localization::multiply
# 2018041500 8-45GBx24PE  ---.-            ----   --.-         ---            --.-           --.-
# 2018041506 8-45GBx24PE  ---.-            ----   --.-         ---            --.-           --.-
# 2018041512 8-45GBx24PE  ---.-            ----   --.-         ---            --.-           --.-
# 2018041518 8-45GBx24PE  ---.-            ----   --.-         ---            --.-           --.-

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
