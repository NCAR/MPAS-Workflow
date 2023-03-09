
class TaskManager:
  def __init__(self, name):
    self.base = name

    # For each of these cylc "task" names, some are family names, while others are marker names
    # + "family" tasks can be used for inheritance; those marked with a * must be used in order
    #   to avoid an error message caused by the ":succeed-all" qualifier
    # + "marker" tasks can be used in dependency graphs only
    #TODO: provide mechanism for multiple serial pre and post tasks
    self.group = self.base # family, all-encompassing
    self.pre = 'Pre'+self.base # marker
    self.init = 'Init'+self.base # family*
    self.execute = self.base+'Exec' # family*
    self.post = self.base+'Post' # marker
    self.finished = self.base+'Finished' # marker
    self.clean = 'Clean'+self.base # family

    self._phases = [
      self.pre,
      self.init,
      self.execute,
      self.post,
      self.finished,
      self.clean,
    ]

class CylcTask(TaskManager):
  def __init__(self, name:str, groupSettings=['']):
    '''
    populate internal task markers and dependencies
    '''

    super().__init__(name)

    # tasks (i.e., cylc runtime)
    self.__t = []

    self.__t += ['''
  [['''+self.group+''']]''']
    self.__t += groupSettings

    for p in self._phases:
      self.__t += ['''
  [['''+p+''']]''']

      # all tasks besides clean inherit from self.group
      if p in [self.pre, self.init, self.execute, self.post, self.finished]:
        self.__t += ['''
    inherit = '''+self.group]

      # required for parent tasks that do not use init and/or execute phases
      if p in [self.init, self.execute]:
        self.__t += ['''
  [['''+p+'''_]]
    inherit = '''+p]

      # all clean tasks derive from Clean base task
      if p == self.clean:
        self.__t += ['''
    inherit = Clean''']

    # dependencies
    self.__d = []
    self.__d += ['''
        # pre => init => execute:succeed-all => post => finished => clean
        # init
        '''+self.pre+''' => '''+self.init+'''

        ## execute after all init complete
        '''+self.init+''':succeed-all => '''+self.execute+'''

        ## post aget all execute complete
        '''+self.execute+''':succeed-all => '''+self.post+'''

        # finished after post, clean after finished
        '''+self.post+''' => '''+self.finished+''' => '''+self.clean]

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

  def tasks(self):
    return self.__t

  def dependencies(self):
    return self.__d
