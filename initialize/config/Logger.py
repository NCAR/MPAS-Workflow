#!/usr/bin/env python3

'''
 (C) Copyright 2023 UCAR

 This software is licensed under the terms of the Apache Licence Version 2.0
 which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
'''

import os

'''
class for logging statements conditionally, based on verbosity.
the value of the CYLC_DEBUG environment variable will control output.
if CYLC_DEBUG is not set, assume verbosity level 1 (some info, all errors)
'''
class Logger():

  # values for passing to log e.g. log("text", level=self.MSG_DEBUG)
  MSG_QUIET = 0 # always print
  MSG_NORMAL = 1 # normal output, suppress if CYLC_DEBUG env var is 0
  MSG_DEBUG = 2 # print if CYLC_DEBUG is >= 2
  MSG_NOISY = 3 # print if CYLC_DEBUG is >= 3
  _msg_level = 1

  def __init__(self):

    # set level for printing via self.log()
    msg_env = os.getenv('CYLC_DEBUG')
    if msg_env is None:
      self._msg_level = 1
    elif msg_env.isdigit():
      self._msg_level = int(msg_env)

    self.logPrefix = self.__class__.__name__+': '

  def log(self, text, *args, **kwargs):
    level = kwargs.get('level', 1)
    if level <= self._msg_level:
      print(self.logPrefix+text)
    return

