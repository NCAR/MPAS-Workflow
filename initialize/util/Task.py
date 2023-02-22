#!/usr/bin/env python3

from initialize.Resource import Resource

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
  # TODO: need some way to make 36 PE only apply to cheyenne and not all PBSPro applications
  maxProcPerNode = 36
  def directives(self):
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
      -l = select='''+select

    return text

TaskFactory = {
  'cheyenne': PBSPro,
}
