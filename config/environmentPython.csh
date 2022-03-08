#!/bin/csh -f

if ( $?config_environmentPython ) exit 0
setenv config_environmentPython 1

source /etc/profile.d/modules.csh
module load python

set success = 1
while ( $success != 0 )
  sleep 1
  source /glade/u/apps/ch/opt/usr/bin/npl/ncar_pylib.csh default
  set success = $?
end
