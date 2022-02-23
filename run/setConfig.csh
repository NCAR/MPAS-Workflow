#!/bin/csh -f

set wd = `pwd`
source run/tools.csh $wd

set thisYAML = $1
set rootKey = $2
set key1 = $3

# retrieve config value
set value = `${getYAMLKey} ${thisYAML} ${rootKey}.${key1}`

setenv $key1 $value
#echo "$key1 = $value"
