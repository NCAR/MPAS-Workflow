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
    'Directory0',
    type=str,
    help='first part of directory name, before member directory'
  )

  ap.add_argument(
    'memberPrefix',
    type=str,
    help='prefix of the member directory; if None, will be left blank'
  )

  ap.add_argument(
    'Directory1',
    type=str,
    help='second part of directory name, after member directory'
  )

  ap.add_argument(
    'File',
    type=str,
    help='common file name for all members'
  )

  ap.add_argument(
    'nDigits',
    type=int,
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
  ap.add_argument(
    '-s', '--shuffle',
    type=bool,
    default=True,
    help='Whether to randomly shuffle the order of ensemble state stubs'
  )

  # parse the arguments
  args = ap.parse_args()

  memberPrefix = args.memberPrefix
  if memberPrefix == 'None':
    memberPrefix = ''

  Directory1 = args.Directory1
  if Directory1 == 'None':
    Directory1 = ''
  else:
    Directory1 += '/'

  yamlFiles = args.yamlFiles

  substitutionString = args.substitutionString
  indent = ''.join([' ']*args.nIndent)
  SelfExclusion = bool(strtobool(args.SelfExclusion))
  shuffle = args.shuffle

  # variational yaml files
  with open(yamlFiles) as f:
    filedata = f.read()

  yamls = OrderedDict()
  for member, file in enumerate(filedata.split('\n')[:-1]):
    yamls[str(member+1)] = file

  membersTemplate = \
'''
members from template:
  template:
    <<: *memberConfig
    filename: '''+args.Directory0+'/'+memberPrefix+'%iMember%/'+Directory1+args.File+'''
  pattern: %iMember%
  start: 1
  zero padding: '''+str(args.nDigits)+'''
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
