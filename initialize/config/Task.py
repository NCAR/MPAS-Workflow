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
    [[[job]]]
      batch system = '''+self.batchSystem+'''
      execution time limit = PT'''+str(int(seconds))+'S'
    if retry is not None:
      text += '''
      execution retry delays = '''+str(retry)

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
    nodes = self.r.getOrDefault('nodes', None)
    if nodes is not None:
      PEPerNode = self.r['PEPerNode']
      memory = self.r.getOrDefault('memory', None)
      if PEPerNode > 1:
        select = str(nodes)+':ncpus='+str(PEPerNode)+':mpiprocs='+str(PEPerNode)
      else:
        select = str(nodes)+':ncpus='+str(PEPerNode)

      if memory is not None:
        select += ':mem='+memory
    else:
      select = None

    unique = {}
    if self.r['queue'] is not None:
      unique['q'] = self.r['queue']
    if self.r['account'] is not None:
      unique['A'] = self.r['account']
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

    if select is not None:
      text += '''
      -l = select='''+select

    return text

class Cheyenne(PBSPro):
  name = 'cheyenne'

TaskLookup = {
  'cheyenne': Cheyenne,
}
