#!/usr/bin/env python3

'''
 (C) Copyright 2023 UCAR

 This software is licensed under the terms of the Apache Licence Version 2.0
 which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
'''

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
