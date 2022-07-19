#!/bin/csh -f

if ( $?config_job ) exit 0
setenv config_job 1

source config/scenario.csh job

$setLocal CPAccountNumber
$setLocal CPQueueName
$setLocal NCPAccountNumber
$setLocal NCPQueueName
$setLocal SingleProcAccountNumber
$setLocal SingleProcQueueName
$setLocal EnsMeanBGQueueName
$setLocal EnsMeanBGAccountNumber

$setLocal InitializationRetry
$setLocal GetAnalysisRetry
$setLocal GetObsRetry
$setLocal ConvertObsRetry
$setLocal VariationalRetry
$setLocal EnsOfVariationalRetry
$setLocal CyclingFCRetry
$setLocal RTPPRetry
$setLocal HofXRetry
$setLocal CleanRetry
$setLocal VerifyObsRetry
$setLocal VerifyModelRetry
