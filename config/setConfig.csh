#!/bin/csh -f

source config/config.csh

# get arguments
set defaultYAML = $1
set thisYAML = $2
set rootKey = $3
set key1 = $4

# retrieve config value
# TODO: for larger config files, this process will get more expensive; move toward:
# (1) only loading sub-sections of the YAML that are needed
# (2) automatically parsing an entire YAML sub-section in its respective csh script
#     instead of retrieving nodes one at a time
# (3) same as (2), but for the entire YAML
set key = "`${getYAMLNode} ${defaultYAML} ${thisYAML} ${rootKey}.${key1} -o key`"
set value = "`${getYAMLNode} ${defaultYAML} ${thisYAML} ${rootKey}.${key1} -o value`"

if ("$value" == None) then
  echo "$0 (ERROR): invalid value for $key1"
  echo "$0 (ERROR): $key1 = $value"
  exit 1
endif

# verbose output, useful for debugging
#echo "$0 (DEBUG): $key1 = $value"

# if value contains spaces, assume it is a list
if ( "$value" =~ *" "*) then
  set $key = ($value)
else
  setenv $key "$value"
endif
