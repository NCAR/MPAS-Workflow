#!/bin/csh -f

source config/config.csh

# get arguments
set defaultYAML = "$1"
set thisYAML = "$2"
set rootKey = "$3"
set key1 = "$4"

# check if config key exists and value is not None
#set key = "`${getYAMLNode} ${defaultYAML} ${thisYAML} ${rootKey}.${key1} -o key`"
#if ( $status != 0 || "$key" =~ *"None"* ) then
#  echo "None"
#  exit 0
#endif
set value = "`${getYAMLNode} ${defaultYAML} ${thisYAML} ${rootKey}.${key1} -o value`"
if ( $status != 0 || "$value" =~ *"None"* ) then
  echo "None"
else
  echo "$value"
endif
