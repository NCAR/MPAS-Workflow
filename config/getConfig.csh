#!/bin/csh -f

source config/config.csh

# get arguments
set defaultYAML = $1
set thisYAML = $2
set rootKey = $3
set key1 = $4

# retrieve config value
set value = `${getYAMLKey} ${defaultYAML} ${thisYAML} ${rootKey}.${key1}`

# return config value
echo $value
