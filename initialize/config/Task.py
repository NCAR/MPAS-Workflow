#!/usr/bin/env python3

'''
 (C) Copyright 2023 UCAR

 This software is licensed under the terms of the Apache Licence Version 2.0
 which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
'''

import sys
from initialize.config.Resource import Resource

class Task():
  def __init__(self, r:Resource):
    self.r = r
    #TODO: add email() method when more systems are supported
    self.email = r.getOrDefault('email', False)
    self.batchSystem = 'background'

  def job(self):
    retry = self.r.get('retry')
    seconds = self.r['seconds']

    text = '''
    execution time limit = PT'''+str(int(seconds))+'S'
    if retry is not None:
      text += '''
    execution retry delays = '''+str(retry)
    text += '''
    platform = '''+self.batchSystem+'_cluster'

    return text

  def directives(self):
    '''
    virtual method
    '''
    raise NotImplementedError()


class PBSPro(Task):
  def __init__(self, r:Resource):
    super().__init__(r)
    self.batchSystem = 'pbs'

  def directives(self):
    unique = {}
    if self.r['queue'] is not None:
      unique['q'] = self.r['queue']
    if self.r['account'] is not None:
      unique['A'] = self.r['account']
    if self.r['job_priority'] is not None:
      unique['l'] = 'job_priority=' + self.r['job_priority']
    unique['j'] = 'oe'
    unique['k'] = 'eod'
    unique['S'] = '/bin/tcsh'

    if self.email: unique['m'] = 'ae'

    flags = ''
    for f, v in unique.items():
       flags +='''
      -'''+f+' = '+v

    text = '''
    [[[directives]]]'''+flags

    nodes = self.r.getOrDefault('nodes', None, int)
    if nodes is not None:
      PEPerNode = self.r['PEPerNode']
      memory = self.r.getOrDefault('memory', None)

      # if the task specifies to use GPU's modify the select statement
      # to route the PBS job to the gpu queue.
      gpu_str = ''
      self.r.log('Task.directives: GPUPerNode:' + str(self.r['GPUPerNode']), level=self.r.MSG_DEBUG)
      if self.r['GPUPerNode'] is not None and self.r['GPUPerNode'] > 0:
        # specifying ngpus in the select statement will send the job to the gpu queue.
        gpu_str = ':ngpus='+str(self.r['GPUPerNode'])
        memory = None # don't specify memory, use whatever is available on the GPU node
        if PEPerNode > self.maxProcPerGpuNode:
          PEPerNode = self.maxProcPerGpuNode
      threads = self.r.getOrDefault('threads', 1, int)
      assert threads*PEPerNode <= self.maxProcPerNode, (
        'PBSPro: too many processors requested -->'+str(threads*PEPerNode))

      select = str(nodes)+':ncpus='+str(PEPerNode)+gpu_str+':mpiprocs='+str(PEPerNode)
      if threads > 1:
        select = str(nodes)+':ncpus='+str(self.maxProcPerNode)+':mpiprocs='+str(PEPerNode)+':ompthreads='+str(threads)
      if memory is not None:
        select += ':mem='+memory

      text += '''
      -l select='''+select

    return text

class CheyenneTask(PBSPro):
  name = 'cheyenne'
  maxProcPerNode = 36
  maxMemPerNode = "45GB"


class DerechoTask(PBSPro):
  name = 'derecho'
  maxProcPerNode = 128
  maxProcPerGpuNode = 64
  maxMemPerNode = "235GB"

  def __init__(self, r:Resource):
    # verify queue and priority settings
    #print('resource defaults', r._defaults)
    if r['queue'] is not None:
      queue = r['queue']
      priority = r['job_priority']
      if priority is not None:
        r.log('calling log via resource, queue is '+queue + ' priority is '+priority, level=r.MSG_DEBUG)
      else:
        r.log('calling log via resource, queue is '+queue, level=r.MSG_DEBUG)
      r.log('resource table: ' + str(r._table), level=r.MSG_NOISY)
      derecho_queues = ['main', 'preempt', 'develop', 'casper@casper-pbs']
      if priority is not None:
        if queue == 'develop':
          r.log('Warning: develop queue does not support priority, priority '+ priority + ' ignored', level=r.MSG_QUIET)
      if queue not in derecho_queues:
        r.log('queue ('+queue+') must be one of ' +', '.join(derecho_queues), level=r.MSG_QUIET)
        if queue == 'economy' or queue == 'premium':
          r.log('use either CriticalPriority or NonCriticalPriority to set priority', level=r.MSG_QUIET)
          r.log(' e.g. CriticalPriority : '+queue, level=r.MSG_QUIET)
        r.log('cylc task not run', level=r.MSG_QUIET)
        sys.exit(1)
    r.convertToDerecho()
    super().__init__(r)


TaskLookup = {
  'cheyenne': CheyenneTask,
  'derecho': DerechoTask,
}
