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
    'directory0',
    type=str,
    help='first part of directory name, before member directory'
  )

  ap.add_argument(
    'directory1',
    type=str,
    help='second part of directory name, after member directory'
  )

  ap.add_argument(
    'memberPrefix',
    type=str,
    help='prefix of the member directory; if None, will be left blank'
  )

  ap.add_argument(
    'File',
    type=str,
    help='common file name for all members'
  )

  ap.add_argument(
    'memberNDigits',
    type=int,
    choices = [1,2,3,4,5,6],
    help='number of digits, including padded zeros, in member directory name'
  )

  ap.add_argument(
    'nMembers',
    type=int,
    help='number of members'
  )

  ap.add_argument(
    'yamlFiles',
    type=str,
    help=textwrap.dedent(
      '''
      Plain text file with list of YAML files that will be modified. When len(yamlFiles) > 1,
      the order is assumed to correspond to the order of background states.
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

  # parse the arguments
  args = ap.parse_args()

  memberPrefix = args.memberPrefix
  if memberPrefix == 'None':
    memberPrefix = ''

  directory1 = args.directory1
  if directory1 == 'None':
    directory1 = ''
  else:
    directory1 += '/'

  yamlFiles = args.yamlFiles

  substitutionString = args.substitutionString
  indent = ''.join([' ']*args.nIndent)
  SelfExclusion = bool(strtobool(args.SelfExclusion))

  # variational yaml files
  with open(yamlFiles) as f:
    filedata = f.read()

  yamls = OrderedDict()
  for member, file in enumerate(filedata.split('\n')[:-1]):
    yamls[str(member+1)] = file

  filename = args.directory0+'/'+memberPrefix+'%iMember%/'+directory1+args.File

  membersTemplate = \
'''
members from template:
  template:
    <<: *memberConfig
    filename: '''+filename+'''
  pattern: %iMember%
  start: 1
  zero padding: '''+str(args.memberNDigits)+'''
'''

  # substitute members template into all yaml files
  for yamlMember, yamlFile in yamls.items():
    nonIndented = membersTemplate

    # nmembers and except depends on the SelfExclusion argument
    if SelfExclusion and len(yamls) > 1:
      nonIndented += \
'''
  nmembers: '''+str(args.nMembers-1)+'''
  except: ['''+yamlMember+''']
'''
    else:
      nonIndented += \
'''
  nmembers: '''+str(args.nMembers)+'''
'''

    replacementString = ''
    for s in nonIndented.split('\n'):
      if s == '': continue
      replacementString+=indent+s+'\n'

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
