class ObsEnsemble(list):
  def __init__(self):

  def append(self, conf:dict):
    self.append(ObsDB(conf))   

class ObsDB:
  def __init__(self, conf:dict):
    self.__directory = str(conf['directory'])
    self.__observers = list(conf['observers'])

  def directory(self):
    return self.__directory

  def observers(self):
    return self.__observers
