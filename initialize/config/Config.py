#!/usr/bin/env python3

'''
 (C) Copyright 2023 UCAR

 This software is licensed under the terms of the Apache Licence Version 2.0
 which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
'''

from collections.abc import Iterable
from copy import deepcopy
import yaml
import sys
import traceback

class Config():
  def __init__(self,
      filename: str,
      defaultsFile:str = None,
    ):

   with open(filename) as file:
     self._table = yaml.load(file, Loader=yaml.FullLoader)

   if defaultsFile is not None:
     with open(defaultsFile) as file:
       self._defaults = yaml.load(file, Loader=yaml.FullLoader)
   else:
     self._defaults = {}

  def extract(self, subKey: str, defaultsFile:str = None):
    tab = deepcopy(self._table.get(subKey, {}))

    if defaultsFile is not None:
      with open(defaultsFile) as file:
        defaults = yaml.load(file, Loader=yaml.FullLoader)
      d = defaults.get(subKey, {})
    else:
      d = deepcopy(self._defaults.get(subKey, {}))

    return tab, d

  def get(self, dotSeparatedKey, typ=None, options=None):
    '''
    get dictionary value for nested dot-separated key
    e.g., get('top.next') tries to retrieve self._table['top']['next']
          if exception ocurrs, try to retrieve self.defaults['top']['next']
          if exception occurs, return None
    '''
    key = dotSeparatedKey.split('.')

    try:
      v = deepcopy(self._table)
      for level in key:
        v = deepcopy(v[level])
    except:
      try:
        v = deepcopy(self._defaults)
        for level in key:
          v = deepcopy(v[level])
      except:
        v = None
    if v is not None:
      if v == 'None': v = None

    if options is not None and v is not None:
      assert isinstance(options, Iterable) and not isinstance(options, str), (
        'options must be a list of valid values or not present at all, not '+str(options))
      #assert v in options, ('invalid value for '+dotSeparatedKey+': '+str(v)+
        #'; choose one of '+str(options))

    if typ is not None and v is not None:
      return typ(v)
    else:
      return v

  def __getitem__(self, key:str):
    return self.get(key)

  def __setitem__(self, key:str, v):
    self._table[key] = v

  def __setitem2__(self, key:str, subkey:str,v):
    self._table[key][subkey] = v

  def getOrDefault(self, key, default, typ=None, options=None):
    '''option to provide default value as second argument'''
    v = self.get(key, typ, options)
    if v is None:
      return default
    else:
      return v

  def has(self, key, typ=None, options=None):
    '''determine if config node is available and has valid value'''
    v = self.get(key, typ, options)
    return (v is not None)

  def getOrDie(self, key, typ=None, options=None):
    '''throw error if node is not available'''
    v = self.get(key, typ, options)
    assert v is not None, ('key ('+key+') is invalid or has None value')
    return v

  def convertToDerecho(self):
    '''
    convert cheyenne specific items to derecho specific ites, e.g. queues, priorities
    '''
    #print('Config resource table', self._table)
    #print('resource defaults', self._defaults)
    self.__convertQueue('queue')


  def __convertQueue(self, attrName:str, subtable:str=None):
    derecho_queues = ['main', 'preempt', 'casper@casper-pbs']

    if subtable != None:
      qAttrName = subtable + '.' + attrName
    else:
      qAttrName = attrName

    if self.has(qAttrName):
      queue = self.get(qAttrName)
      if queue not in derecho_queues:
        newqueue = 'main'
        # do we ever want to use the preempt queue? this could lead to starvation.
        #if queue == 'share':
          #newqueue = 'preempt'
        print('Config converting queue:', queue, ' to:', newqueue)
        if subtable != None:
          self.__setitem2__(subtable, attrName, newqueue)
        else:
          self.__setitem__(attrName, newqueue)

        # add a priority if converting a top level queue
        #print('Config table', self._table)
        #print('job_priority:', self['job_priority'], ' ', self.has('hpc.job_priority'))
        if subtable == None and self.has('hpc.job_priority') == False and queue in ['economy', 'premium']:
          self.__setitem__('job_priority', queue)
          print('Adding job_priority ', queue)

        '''
        print('################################################################################')
        traceback.print_stack(file=sys.stdout)
        print('################################################################################')
        '''

        #print('Config resource table', self._table)
        #print('Config resource defaults', self._defaults)

