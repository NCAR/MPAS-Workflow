#!/usr/bin/env python3

from initialize.config.Resource import Resource

class Task():
  def __init__(self, r:Resource):
    self.r = r
    #TODO: add email() method when more systems are supported
    self.email = r.getOrDefault('email', False)

  def job(self):
    retry = self.r.get('retry')
    seconds = self.r['seconds']

    text = '''
    [[[job]]]
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
  def directives(self):
    nodes = self.r.getOrDefault('nodes', None)
    if nodes is not None:
      PEPerNode = self.r['PEPerNode']
      memory = self.r.getOrDefault('memory', None)
      select = str(nodes)+':ncpus='+str(PEPerNode)+':mpiprocs='+str(PEPerNode)
      if memory is not None:
        select += ':mem='+memory
    else:
      select = None

    unique = {}
    unique['q'] = self.r['queue']
    unique['A'] = self.r['account']
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
