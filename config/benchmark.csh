#!/bin/csh -f

if ( $?config_benchmark ) exit 0
setenv config_benchmark 1

source config/scenario.csh

# setLocal is a helper function that picks out a configuration node
# under the "benchmark" key of scenarioConfig
setenv baseConfig scenarios/base/benchmark.yaml
setenv getLocalOrNone "source $getConfigOrNone $baseConfig $scenarioConfig benchmark"

# BenchmarkExperimentDirectory
setenv benchmark__ExperimentDirectory "`$getLocalOrNone ExperimentDirectory`"
