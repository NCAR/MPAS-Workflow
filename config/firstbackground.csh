#!/bin/csh -f

if ( $?config_firstbackground ) exit 0
setenv config_firstbackground 1

source config/members.csh
source config/model.csh
source config/scenario.csh firstbackground

setenv firstbackground__resource "`$getLocalOrNone resource`"

foreach parameter (directory filePrefix staticDirectory staticPrefix maxMembers memberFormat PrepareFirstBackground)
  set p = "`$getLocalOrNone $firstbackground__resource.$outerMesh.${parameter}`"
  if ("$p" == None) then
    set p = "`$getLocalOrNone $firstbackground__resource.common.${parameter}`"
  endif
  if ("$p" == None) then
    set p = "`$getLocalOrNone defaults.${parameter}`"
  endif
  set firstbackground__${parameter}Outer = "$p"
end

set firstbackground__staticPrefixOuter = `echo "$firstbackground__staticPrefixOuter" \
  | sed 's@{{nCells}}@'${nCellsOuter}'@' \
  `
if ($nMembers > $firstbackground__maxMembersOuter) then
  echo "firstbackground (ERROR): nMembers must be <= maxMembersOuter ($firstbackground__maxMembersOuter)"
  exit 1
endif
if ("$firstbackground__PrepareFirstBackgroundOuter" == None) then
  echo "firstbackground (ERROR): PrepareFirstBackground must be defined"
  exit 1
endif
if ("$firstbackground__staticDirectoryOuter" == None) then
  echo "firstbackground (ERROR): staticDirectory must be defined"
  exit 1
endif

foreach parameter (directory filePrefix staticDirectory staticPrefix maxMembers memberFormat PrepareFirstBackground)
  set p = "`$getLocalOrNone $firstbackground__resource.$innerMesh.${parameter}`"
  if ("$p" == None) then
    set p = "`$getLocalOrNone $firstbackground__resource.common.${parameter}`"
  endif
  if ("$p" == None) then
    set p = "`$getLocalOrNone defaults.${parameter}`"
  endif
  set firstbackground__${parameter}Inner = "$p"
end

#if ($nMembers > $firstbackground__maxMembersInner) then
#  echo "firstbackground (ERROR): nMembers must be <= maxMembersInner ($firstbackground__maxMembersInner)"
#  exit 1
#endif

set firstbackground__staticPrefixInner = `echo "$firstbackground__staticPrefixInner" \
  | sed 's@{{nCells}}@'${nCellsInner}'@' \
  `

foreach parameter (directory filePrefix staticDirectory staticPrefix maxMembers memberFormat PrepareFirstBackground)
  set p = "`$getLocalOrNone $firstbackground__resource.$ensembleMesh.${parameter}`"
  if ("$p" == None) then
    set p = "`$getLocalOrNone $firstbackground__resource.common.${parameter}`"
  endif
  if ("$p" == None) then
    set p = "`$getLocalOrNone defaults.${parameter}`"
  endif
  set firstbackground__${parameter}Ensemble = "$p"
end

#if ($nMembers > $firstbackground__maxMembersEnsemble) then
#  echo "firstbackground (ERROR): nMembers must be <= maxMembersEnsemble ($firstbackground__maxMembersEnsemble)"
#  exit 1
#endif

set firstbackground__staticPrefixEnsemble = `echo "$firstbackground__staticPrefixEnsemble" \
  | sed 's@{{nCells}}@'${nCellsEnsemble}'@' \
  `


##################################
# auto-generate cylc include files
##################################

if ( ! -e include/tasks/auto/firstbackground.rc ) then
cat >! include/tasks/auto/firstbackground.rc << EOF
  [[LinkWarmStartBackgrounds]]
    inherit = BATCH
    script = \$origin/applications/LinkWarmStartBackgrounds.csh
    [[[job]]]
      # give longer for higher resolution and more EDA members
      # TODO: set time limit based on outerMesh AND (number of members OR
      #       independent task for each member)
      execution time limit = PT10M
      execution retry delays = 1*PT5S
EOF

endif

## Mini-workflow that prepares the firstbackground for the outerMesh
if ( ! -e include/variables/auto/firstbackground.rc ) then
cat >! include/variables/auto/firstbackground.rc << EOF
{% set PrepareFirstBackgroundOuter = "${firstbackground__PrepareFirstBackgroundOuter}" %}
EOF

endif
