#!/bin/csh -f

set wd = `pwd`
source config/tools.csh $wd

# get arguments
set thisYAML = $1
set configSection = $2
set key = $3

set defaultYAML = config/cases/defaults.yaml

# retrieve config value
set value = `${getYAMLKey} ${defaultYAML} ${thisYAML} ${configSection}.${key}`

# return config value
echo $value
