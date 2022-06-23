#!/usr/bin/env python3

import argparse
from collections import OrderedDict
from distutils.util import strtobool
import random
import re
import textwrap

# usage:
# python substituteEnsembleB.py stateFiles yamlFiles substitutionString nIndent SelfExclusion

def substituteEnsembleB():
  # Parse command line
  ap = argparse.ArgumentParser()

  ap.add_argument(
    'stateFiles',
    type=str,
    help='Plain text file with list of ensemble state files'
  )
  ap.add_argument(
    'yamlFiles',
    type=str,
    help=textwrap.dedent(
      '''
      Plain text file with list of YAML files that will be modified. When len(yamlFiles) > 1,
      the order is assumed to correspond to stateFiles.
      ''')
  )
  ap.add_argument(
    'substitutionString',
    type=str,
    help='String to be substituted'
  )
  ap.add_argument(
    'nIndent',
    type=int,
    help='number of spaces to indent each yaml line'
  )
  ap.add_argument(
    'SelfExclusion',
    type=str,
    default="False",
    help='Whether to use self-exclusion, excluding own member (index in yamlFiles) from yaml'
  )
  ap.add_argument(
    '-s', '--shuffle',
    type=bool,
    default=True,
    help='Whether to randomly shuffle the order of ensemble state stubs'
  )

  # parse the arguments
  args = ap.parse_args()

  stateFiles = args.stateFiles
  yamlFiles = args.yamlFiles

  substitutionString = args.substitutionString
  indent = ''.join([' ']*args.nIndent)
  SelfExclusion = bool(strtobool(args.SelfExclusion))
  shuffle = args.shuffle

  # create ensemble member state yaml stubs
  with open(stateFiles) as f:
    filedata = f.read()

  states = OrderedDict()
  for member, file in enumerate(filedata.split('\n')[:-1]):
    stub = indent+'- <<: *memberConfig\n'
    stub = stub+indent+'  filename: '+file+'\n'
    states[str(member)] = stub

  # variational yaml files
  with open(yamlFiles) as f:
    filedata = f.read()

  yamls = OrderedDict()
  for member, file in enumerate(filedata.split('\n')[:-1]):
    yamls[str(member)] = file

  # substitute all relevant ensemble state stubs into all yaml files
  for yamlMember, yamlFile in yamls.items():
    # first shuffle the stub order so that file reading order is diverse
    # across variational application instances
    stateMembers = list(states.keys())
    if shuffle: random.shuffle(stateMembers)

    # populate replacementString with yaml stubs
    replacementString = indent+'members:\n'

    for stateMember in stateMembers:
      if SelfExclusion and yamlMember==stateMember and len(yamls) > 1: continue
      replacementString += states[stateMember]


    # read yamlFile
    with open(yamlFile) as f:
      filedata = f.read()

    # replace for substitutionString
    filedata = filedata.replace('{{'+substitutionString+'}}\n', replacementString)

    # replace yamlFile with new version
    f = open(yamlFile, 'w')
    f.write(filedata)
    f.close()

if __name__ == '__main__': substituteEnsembleB()
