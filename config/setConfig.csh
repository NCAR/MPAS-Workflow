#!/bin/csh -f

set wd = `pwd`
source config/tools.csh $wd

set thisYAML = $1
set rootKey = $2
set key1 = $3

set defaultYAML = config/cases/defaults.yaml

# retrieve config value
set value = `${getYAMLKey} ${defaultYAML} ${thisYAML} ${rootKey}.${key1}`

setenv $key1 $value
#echo "$key1 = $value"
