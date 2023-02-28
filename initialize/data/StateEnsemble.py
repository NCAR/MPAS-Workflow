from initialize.components.Model import Mesh

class StateEnsemble(list):
  def __init__(self, mesh:Mesh):
    self.__mesh = mesh

  def append(self, conf:dict):
    self.append(State(conf, self.__mesh))   

  def mesh(self):
    return self.__mesh

class State:
  def __init__(self, conf:dict, mesh:Mesh):
    self.__directory = str(conf['directory'])
    self.__prefix = str(conf['prefix'])
    self.__mesh = mesh

#  def location(self):
#    return self.__directory+'/'+self.__prefix

  def directory(self):
    return self.__directory

  def prefix(self):
    return self.__prefix

  def mesh(self):
    return self.__mesh
