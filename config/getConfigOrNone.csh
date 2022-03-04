#!/bin/csh -f

source config/config.csh

# get arguments
set defaultYAML = "$1"
set thisYAML = "$2"
set rootKey = "$3"
set key1 = "$4"

set value = "`${getYAMLNode} ${defaultYAML} ${thisYAML} ${rootKey}.${key1} -o value`"
if ( $status != 0 || "$value" =~ *"None"* ) then
  echo "None"
else
  echo "$value"
endif
