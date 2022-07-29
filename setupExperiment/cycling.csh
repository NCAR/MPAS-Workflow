#!/bin/csh -f

source setupExperiment/parseConfig.csh

## experiment name
if ("$ExperimentName" == None) then

  source config/applications/rtpp.csh
  source config/auto/variational.csh
  source config/auto/members.csh
  source config/auto/model.csh


  # derive experiment title parts from critical config elements
  #(1) DAType
  set ExpBase = ${DAType}

  #(2) ensemble-related settings
  set ExpEnsSuffix = ''
  if ($nMembers > 1) then
    set ExpBase = eda_${ExpBase}
    if ($EDASize > 1) then
      set ExpEnsSuffix = '_NMEM'${nDAInstances}x${EDASize}
      if ($MinimizerAlgorithm == $BlockEDA) then
        set ExpEnsSuffix = ${ExpEnsSuffix}Block
      endif
    else
      set ExpEnsSuffix = '_NMEM'${nMembers}
    endif
    if (${rtpp__relaxationFactor} != "0.0") set ExpEnsSuffix = ${ExpEnsSuffix}_RTPP${rtpp__relaxationFactor}
    if (${SelfExclusion} == True) set ExpEnsSuffix = ${ExpEnsSuffix}_SelfExclusion
    if (${ABEInflation} == True) set ExpEnsSuffix = ${ExpEnsSuffix}_ABEI_BT${ABEIChannel}
  endif

  #(3) inner iteration counts
  set ExpIterSuffix = ''
  foreach nInner ($nInnerIterations)
    set ExpIterSuffix = ${ExpIterSuffix}-${nInner}
  end
  if ( $nOuterIterations > 0 ) then
    set ExpIterSuffix = ${ExpIterSuffix}-iter
  endif

  #(4) observation selection
  setenv ExpObsSuffix ''
  foreach obs ($observations)
    set isBench = False
    foreach benchObs ($benchmarkObservations)
      if ("$obs" =~ *"$benchObs"*) then
        set isBench = True
      endif
    end
    if ( $isBench == False ) then
      setenv ExpObsSuffix ${ExpObsSuffix}_${obs}
    endif
  end

  setenv ExperimentName ${ExpBase}
  setenv ExperimentName ${ExperimentName}${ExpIterSuffix}
  setenv ExperimentName ${ExperimentName}${ExpObsSuffix}
  setenv ExperimentName ${ExperimentName}${ExpEnsSuffix}

  # MeshesDescriptor used for automated experiment naming conventions
  setenv MeshesDescriptor O
  if ("$outerMesh" != "$innerMesh") then
    setenv MeshesDescriptor ${MeshesDescriptor}${outerMesh}
  endif
  setenv MeshesDescriptor ${MeshesDescriptor}I
  if ("$innerMesh" != "$ensembleMesh") then
    #TODO: remove when this is no longer a limitation
    echo "$0 (ERROR): innerMesh ($innerMesh) must equal ensembleMesh($ensembleMesh)"
    exit 1
    #setenv MeshesDescriptor ${MeshesDescriptor}${innerMesh}
  endif
  setenv MeshesDescriptor ${MeshesDescriptor}E${ensembleMesh}

  setenv ExperimentName ${ExperimentName}_${MeshesDescriptor}
endif

source setupExperiment/generateExperimentConfig.csh
