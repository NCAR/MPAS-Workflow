#!/bin/csh -f

if ( $?config_externalanalyses ) exit 0
setenv config_externalanalyses 1

source config/model.csh

source config/scenario.csh externalanalyses

$setNestedExternalanalyses resource

# outer
set name = Outer
set mesh = "$outerMesh"
set ncells = "$nCellsOuter"
foreach parameter (externalDirectory filePrefix Vtable UngribPrefix PrepareExternalAnalysisTasks retry)
  set p = "`$getLocalOrNone $externalanalyses__resource.$mesh.${parameter}`"
  if ("$p" == None) then
    set p = "`$getLocalOrNone $externalanalyses__resource.common.${parameter}`"
  endif
  if ("$p" == None) then
    set p = "`$getLocalOrNone defaults.${parameter}`"
  endif
  if ("$parameter" == filePrefix) then
    set externalanalyses__${parameter}${name} = `echo "$p" | sed 's@{{nCells}}@'$ncells'@'`
  else if ("$parameter" == PrepareExternalAnalysisTasks) then
    set tmp = ""
    foreach task ($p)
      set tmp = "$tmp"`echo '"'$task'"' | sed 's@mesh@'$mesh'@g'`", "
    end
    set externalanalyses__${parameter}${name} = "$tmp"
  else
    set externalanalyses__${parameter}${name} = "$p"
  endif
end

# assume UngribPrefix and Vtable are always identical across meshes
set externalanalyses__UngribPrefix = "$externalanalyses__UngribPrefixOuter"
unset externalanalyses__UngribPrefixOuter

set externalanalyses__Vtable = "$externalanalyses__VtableOuter"
unset externalanalyses__VtableOuter

# inner
set name = Inner
set mesh = "$innerMesh"
set ncells = "$nCellsInner"
foreach parameter (externalDirectory filePrefix PrepareExternalAnalysisTasks)
  set p = "`$getLocalOrNone $externalanalyses__resource.$mesh.${parameter}`"
  if ("$p" == None) then
    set p = "`$getLocalOrNone $externalanalyses__resource.common.${parameter}`"
  endif
  if ("$p" == None) then
    set p = "`$getLocalOrNone defaults.${parameter}`"
  endif
  if ("$parameter" == filePrefix) then
    set externalanalyses__${parameter}${name} = `echo "$p" | sed 's@{{nCells}}@'$ncells'@'`
  else if ("$parameter" == PrepareExternalAnalysisTasks) then
    set tmp = ""
    foreach task ($p)
      set tmp = "$tmp"`echo '"'$task'"' | sed 's@mesh@'$mesh'@g'`", "
    end
    set externalanalyses__${parameter}${name} = "$tmp"
  else
    set externalanalyses__${parameter}${name} = "$p"
  endif
end

# ensemble
set name = Ensemble
set mesh = "$ensembleMesh"
set ncells = "$nCellsEnsemble"
foreach parameter (externalDirectory filePrefix PrepareExternalAnalysisTasks)
  set p = "`$getLocalOrNone $externalanalyses__resource.$mesh.${parameter}`"
  if ("$p" == None) then
    set p = "`$getLocalOrNone $externalanalyses__resource.common.${parameter}`"
  endif
  if ("$p" == None) then
    set p = "`$getLocalOrNone defaults.${parameter}`"
  endif
  if ("$parameter" == filePrefix) then
    set externalanalyses__${parameter}${name} = `echo "$p" | sed 's@{{nCells}}@'$ncells'@'`
  else if ("$parameter" == PrepareExternalAnalysisTasks) then
    set tmp = ""
    foreach task ($p)
      set tmp = "$tmp"`echo '"'$task'"' | sed 's@mesh@'$mesh'@g'`", "
    end
    set externalanalyses__${parameter}${name} = "$tmp"
  else
    set externalanalyses__${parameter}${name} = "$p"
  endif
end


##################################
# auto-generate cylc include files
##################################

if ( ! -e include/tasks/externalanalyses.rc ) then 
cat >! include/tasks/externalanalyses.rc << EOF
## Analyses generated outside MPAS-Workflow
  [[GetGFSAnalysisFromRDA]]
    inherit = BATCH
    script = \$origin/GetGFSAnalysisFromRDA.csh
    [[[job]]]
      execution time limit = PT20M
      execution retry delays = $externalanalyses__retryOuter
  [[GetGFSanalysisFromFTP]]
    inherit = BATCH
    script = \$origin/GetGFSAnalysisFromFTP.csh
    [[[job]]]
      execution time limit = PT20M
      execution retry delays = $externalanalyses__retryOuter

  [[UngribExternalAnalysis]]
    inherit = BATCH
    script = \$origin/UngribExternalAnalysis.csh
    [[[job]]]
      execution time limit = PT5M
      execution retry delays = 2*PT30S
    # currently UngribExternalAnalysis has to be on Cheyenne, because ungrib.exe is built there
    # TODO: build ungrib.exe on casper, remove CP directives below
    [[[directives]]]
      -q = {{CPQueueName}}
      -A = {{CPAccountNumber}}

{% for mesh in allMeshes %}
  [[LinkExternalAnalysis-{{mesh}}]]
    inherit = BATCH
    script = \$origin/LinkExternalAnalysis.csh "{{mesh}}"
    [[[job]]]
      execution time limit = PT30S
      execution retry delays = $externalanalyses__retryOuter
{% endfor %}
EOF

endif

## Mini-workflows that prepare cold-start initial condition files from an external analysis
if ( ! -e include/variables/externalanalyses.rc ) then 
cat >! include/variables/externalanalyses.rc << EOF
{% set PrepareExternalAnalysisTasksOuter = [${externalanalyses__PrepareExternalAnalysisTasksOuter}] %}
{% set PrepareExternalAnalysisOuter = " => ".join(PrepareExternalAnalysisTasksOuter) %}

{% set PrepareExternalAnalysisTasksInner = [${externalanalyses__PrepareExternalAnalysisTasksInner}] %}
{% set PrepareExternalAnalysisInner = " => ".join(PrepareExternalAnalysisTasksInner) %}

{% set PrepareExternalAnalysisTasksEnsemble = [${externalanalyses__PrepareExternalAnalysisTasksEnsemble}] %}
{% set PrepareExternalAnalysisEnsemble = " => ".join(PrepareExternalAnalysisTasksEnsemble) %}

# Use external analysis for sea surface updating
{% set PrepareSeaSurfaceUpdate = PrepareExternalAnalysisOuter %}
EOF

endif

