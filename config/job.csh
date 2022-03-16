#!/bin/csh -f

if ( $?config_job ) exit 0
setenv config_job 1

source config/scenario.csh

# setLocal is a helper function that picks out a configuration node
# under the "job" key of scenarioConfig
setenv baseConfig scenarios/base/job.yaml
setenv setLocal "source $setConfig $baseConfig $scenarioConfig job"

$setLocal CPAccountNumber
$setLocal CPQueueName
$setLocal NCPAccountNumber
$setLocal NCPQueueName
$setLocal SingleProcAccountNumber
$setLocal SingleProcQueueName
$setLocal EnsMeanBGQueueName
$setLocal EnsMeanBGAccountNumber

$setLocal InitializationRetry
$setLocal VariationalRetry
$setLocal EnsOfVariationalRetry
$setLocal CyclingFCRetry
$setLocal RTPPInflationRetry
$setLocal HofXRetry
$setLocal CleanRetry
#$setLocal VerifyObsRetry
#$setLocal VerifyModelRetry
