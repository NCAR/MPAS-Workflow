#!/bin/csh -f

if ( $?config_verification ) exit 0
setenv config_verification 1

#####################
## Verification tools
#####################
#TODO: add these to the repo, possibly under a verification directory
set commonVerificationDir = /glade/work/guerrett/pandac/fixed_input/graphics_obs+model
setenv pyObsDir ${commonVerificationDir}
setenv pyModelDir ${commonVerificationDir}
