#!/bin/csh -f

## job length and node/pe requirements

## Uniform 120km mesh
## ------------------

## job length and node/pe requirements
setenv CyclingFCJobMinutes 5
setenv CyclingFCNodes 4
setenv CyclingFCPEPerNode 32

setenv ExtendedFCJobMinutes 40
setenv ExtendedFCNodes ${CyclingFCNodes}
setenv ExtendedFCPEPerNode ${CyclingFCPEPerNode}

setenv HofXJobMinutes 10
setenv HofXNodes 1
setenv HofXPEPerNode 36
setenv HofXMemory 109

setenv VerifyObsNodes 1
setenv VerifyObsPEPerNode 36
setenv VerifyModelNodes 1
setenv VerifyModelPEPerNode 36

setenv CyclingDAJobMinutes 25
setenv CyclingDAMemory 45
#setenv CyclingDAMemory 109
if ( "$DAType" =~ *"eda"* ) then
  setenv CyclingDANodesPerMember 2
  setenv CyclingDAPEPerNode      18
else
  setenv CyclingDANodesPerMember 4
  setenv CyclingDAPEPerNode      32
endif

setenv CyclingInflationJobMinutes 25
setenv CyclingInflationMemory 109
setenv CyclingInflationNodesPerMember ${HofXNodes}
setenv CyclingInflationPEPerNode      ${HofXPEPerNode}

@ CyclingDAPEPerMember = ${CyclingDANodesPerMember} * ${CyclingDAPEPerNode}
setenv CyclingDAPEPerMember ${CyclingDAPEPerMember}

@ CyclingDANodes = ${CyclingDANodesPerMember} * ${nEnsDAMembers}
setenv CyclingDANodes ${CyclingDANodes}
