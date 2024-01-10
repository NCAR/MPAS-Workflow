#!/usr/bin/env python3

'''
 (C) Copyright 2023 UCAR

 This software is licensed under the terms of the Apache Licence Version 2.0
 which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
'''

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

    print('job() text:', text)
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
      threads = self.r.getOrDefault('threads', 1, int)
      assert threads*PEPerNode <= self.maxProcPerNode, (
        'PBSPro: too many processors requested -->'+str(threads*PEPerNode))

      memory = self.r.getOrDefault('memory', None)
      select = str(nodes)+':ncpus='+str(PEPerNode)+':mpiprocs='+str(PEPerNode)
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
  maxMemPerNode = "235GB"

  def __init__(self, r:Resource):
    # convert any cheyenne queue's to derecho
    #print('resource table', r._table)
    #print('resource defaults', r._defaults)
    r.convertToDerecho()
    super().__init__(r)


TaskLookup = {
  'cheyenne': CheyenneTask,
  'derecho': DerechoTask,
}
