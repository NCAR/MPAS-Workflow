#!/bin/csh -f

if ( $?config_members ) exit 0
setenv config_members 1

source config/scenario.csh members

setenv nMembers "`$getLocalOrNone n`"
if ("$nMembers" == None) then
  setenv nMembers 0
endif

if ( ! -e include/variables/auto/members.rc ) then
cat >! include/variables/auto/members.rc << EOF
{% set nMembers = ${nMembers} %} #integer
EOF

endif
