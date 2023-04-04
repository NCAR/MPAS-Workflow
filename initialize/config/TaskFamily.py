#!/usr/bin/env python3

'''
 (C) Copyright 2023 UCAR

 This software is licensed under the terms of the Apache Licence Version 2.0
 which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
'''

from copy import deepcopy

placeholdertask = 'PlaceHolder'

class TaskFamilyBase:
  def __init__(self, name:str, initialize:bool, execute:bool):
    self.base = name

    # For each of these cylc "task" names, some are family names, while others are marker names
    # + "family" tasks can be used for inheritance; those marked with a * must be used in order
    #   to avoid an error message caused by the ":succeed-all" qualifier
    # + "marker" tasks can be used in dependency graphs only
    #TODO: provide mechanism for multiple serial pre and post tasks
    self.group = self.base+'Family' # family, all-encompassing
    self.pre = 'Pre'+self.base+'__' # marker
    self.init = 'Init'+self.base # family*
    self.execute = self.base+'Exec' # family*
    self.post = self.base+'Post__' # marker
    self.finished = self.base+'Finished__' # marker
    self.clean = 'Clean'+self.base # family

    # add all phases as tasks in case they are referenced externally
    self._tPhases = [
      self.pre,
      self.init,
      self.execute,
      self.post,
      self.finished,
      self.clean,
    ]

    # allow for parent app to control whether execute and initialize are added to
    # internal dependencies
    self._dPhases = deepcopy(self._tPhases)
    if not initialize: self._dPhases.remove(self.init)
    if not execute: self._dPhases.remove(self.execute)

    # _multiple tasks may be inherited by 1 or more parent tasks
    self._multiple = [self.init, self.execute]
    self._placeholders = [self.pre, self.post, self.finished]

class CylcTaskFamily(TaskFamilyBase):
  def __init__(self,
    name:str,
    groupSettings=[''],
    initialize:bool=True,
    execute:bool=True,
  ):
    '''
    populate internal task markers and dependencies
    '''

    super().__init__(name, initialize, execute)

    # tasks (i.e., cylc runtime)
    self.__t = []

    self.__t += ['''
  '''+self.wrap(self.group)]
    self.__t += groupSettings

    self.__d = []

  def addDependencies(self, d_:list):
    for d in d_:
      dStr = '''
        '''+d+' => '+self.pre
      if dStr not in self.__d:
        self.__d += [dStr]

  def addFollowons(self, f_:list):
    for f in f_:
      fStr = '''
        '''+self.finished+' => '+f
      if fStr not in self.__d:
        self.__d += [fStr]

  @staticmethod
  def wrap(t):
    return '[['+t+']]'

  @staticmethod
  def inherit(t):
    return '''
    inherit = '''+t

  def updateTasks(self, parentTasks, parentDependencies):
    allTasks = ''.join(parentTasks)
    allDependencies = ''.join(parentDependencies)

    t = []
    for p in self._tPhases:
      tStr = '''
  '''+self.wrap(p)
      if (p in allTasks or p in allDependencies) and tStr not in allTasks:
        t += [tStr]

        inherit = []
        if p == self.clean:
          # all clean tasks derive from Clean base task
          inherit.append('Clean')

        else:
          # all tasks besides clean inherit from self.group
          inherit.append(self.group)

        if p in self._placeholders:
          inherit.append(placeholdertask)

        t += [self.inherit(','.join(inherit))]

        # required for multi-tasks when parent does not inherit these phases
        if p in self._multiple:
          t += ['''
  '''+self.wrap(p+'__')+self.inherit(','.join([p, placeholdertask]))]

    return parentTasks+self.__t+t

  def updateDependencies(self, parentDependencies):
    allDependencies = ''.join(parentDependencies)

    d = []
    # general dependency graph:
    #   pre => init:succeed-all => execute:succeed-all => post => finished => clean
    for i, p in enumerate(self._dPhases[:-1]):
      if p in self._multiple:
        success = ':succeed-all'
      else:
        success = ''

      p_next = self._dPhases[i+1]

      dStr = '''
        '''+p+success+''' => '''+p_next

      if dStr not in allDependencies:
        d += [dStr]

    return parentDependencies+self.__d+d
