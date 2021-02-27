#!/bin/csh -f

## job length and node/pe requirements

# Uniform 30km mesh
# -----------------
setenv CyclingFCJobMinutes 10
setenv CyclingFCNodes 8
setenv CyclingFCPEPerNode 32

setenv ExtendedFCJobMinutes 60
setenv ExtendedFCNodes ${CyclingFCNodes}
setenv ExtendedFCPEPerNode ${CyclingFCPEPerNode}

setenv HofXJobMinutes 10
setenv HofXNodes 32
setenv HofXPEPerNode 16
setenv HofXMemory 109

setenv VerifyObsNodes 1
setenv VerifyObsPEPerNode 36
setenv VerifyModelNodes 1
setenv VerifyModelPEPerNode 36

setenv CyclingDAJobMinutes 25
setenv CyclingDAMemory 109
if ( "$DAType" =~ *"eda"* ) then
  setenv CyclingDANodesPerMember 64
  setenv CyclingDAPEPerNode 8
else
  setenv CyclingDANodesPerMember 64
  setenv CyclingDAPEPerNode 8
endif

setenv CyclingInflationJobMinutes 25
setenv CyclingInflationMemory 109
setenv CyclingInflationNodesPerMember ${HofXNodes}
setenv CyclingInflationPEPerNode      ${HofXPEPerNode}

@ CyclingDAPEPerMember = ${CyclingDANodesPerMember} * ${CyclingDAPEPerNode}
setenv CyclingDAPEPerMember ${CyclingDAPEPerMember}

@ CyclingDANodes = ${CyclingDANodesPerMember} * ${nEnsDAMembers}
setenv CyclingDANodes ${CyclingDANodes}
