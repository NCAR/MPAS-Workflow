#!/bin/csh -f

source config/config.csh

# get arguments
set defaultYAML = "$1"
set thisYAML = "$2"
set rootKey = "$3"
set key1 = "$4"

# retrieve config value
set value = "`${getYAMLNode} ${defaultYAML} ${thisYAML} ${rootKey}.${key1} -o value`"

# substitute "__" for "." in nested key
set key = "${rootKey}.${key1}"
set key = `echo "$key" | sed 's@\.@__@g'`

if ("$value" =~ *"None"*) then
  echo "$0 (ERROR): invalid value for $key"
  echo "$0 (ERROR): $key = $value"
  exit 1
endif

# verbose output, useful for debugging
#echo "$0 (DEBUG): $key = $value"

# if value contains spaces, assume it is a list
if ( "$value" =~ *" "*) then
  set $key = ($value)
else
  setenv $key "$value"
endif
