#!/usr/bin/env python3

from initialize.config.Config import Config

class SubConfig(Config):
  def __init__(self,
      table:dict = {},
      defaults:dict = {},
    ):
    self._table = table
    self._defaults = defaults

  @ classmethod
  def fromConfig(cls,
      parent:Config,
      subKey:str,
      defaultsFile:str = None,
    ):
    table, defaults = parent.extract(subKey, defaultsFile)
    return cls(table, defaults)
