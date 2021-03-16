#!/bin/csh -f

source config/experiment.csh

#
# static job submission settings
# =============================================

## *AccountNumber
# OPTIONS: NMMM0015, NMMM0043
setenv StandardAccountNumber NMMM0043
setenv CYAccountNumber ${StandardAccountNumber}
setenv VFAccountNumber ${StandardAccountNumber}

## *QueueName
# OPTIONS: economy, regular, premium
setenv CYQueueName premium
setenv VFQueueName economy

if ($ABEInflation == True) then
  setenv EnsMeanBGQueueName ${CYQueueName}
  setenv EnsMeanBGAccountNumber ${CYAccountNumber}
else
  setenv EnsMeanBGQueueName ${VFQueueName}
  setenv EnsMeanBGAccountNumber ${VFAccountNumber}
endif

setenv CyclingDARetry '1*PT30S'
setenv CyclingFCRetry '2*PT30S'
setenv RTPPInflationRetry '2*PT30S'
setenv HofXRetry '2*PT30S'
#setenv VerifyObsRetry '1*PT30S'
#setenv VerifyModelRetry '1*PT30S'
