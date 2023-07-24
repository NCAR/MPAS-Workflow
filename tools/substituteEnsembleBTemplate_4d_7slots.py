#!/usr/bin/env python3

import argparse
from collections import OrderedDict
from distutils.util import strtobool
import random
import re
import textwrap

# usage:
# python substituteEnsembleB_4d_7slots.py stateFiles yamlFiles substitutionString nIndent SelfExclusion

def substituteEnsembleB_4d_7slots():
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
    'File1',
    type=str,
    help='common file name for all members'
  )

  ap.add_argument(
    'Date1',
    type=str,
    help='common Date for all members'
  )

  ap.add_argument(
    'File2',
    type=str,
    help='common file name 2 for all members'
  )

  ap.add_argument(
    'Date2',
    type=str,
    help='common Date for all members'
  )

  ap.add_argument(
    'File3',
    type=str,
    help='common file name 3 for all members'
  )

  ap.add_argument(
    'Date3',
    type=str,
    help='common Date for all members'
  )

  ap.add_argument(
    'File4',
    type=str,
    help='common file name 3 for all members'
  )

  ap.add_argument(
    'Date4',
    type=str,
    help='common Date for all members'
  )

  ap.add_argument(
    'File5',
    type=str,
    help='common file name 3 for all members'
  )

  ap.add_argument(
    'Date5',
    type=str,
    help='common Date for all members'
  )

  ap.add_argument(
    'File6',
    type=str,
    help='common file name 3 for all members'
  )

  ap.add_argument(
    'Date6',
    type=str,
    help='common Date for all members'
  )

  ap.add_argument(
    'File7',
    type=str,
    help='common file name 3 for all members'
  )

  ap.add_argument(
    'Date7',
    type=str,
    help='common Date for all members'
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

  #filename1 = args.directory0+'/'+memberPrefix+'%iMember%/'+directory1+args.File1
  #filename2 = args.directory0+'/'+memberPrefix+'%iMember%/'+directory1+args.File2
  #filename3 = args.directory0+'/'+memberPrefix+'%iMember%/'+directory1+args.File3
  #filename4 = args.directory0+'/'+memberPrefix+'%iMember%/'+directory1+args.File4
  #filename5 = args.directory0+'/'+memberPrefix+'%iMember%/'+directory1+args.File5
  #filename6 = args.directory0+'/'+memberPrefix+'%iMember%/'+directory1+args.File6
  #filename7 = args.directory0+'/'+memberPrefix+'%iMember%/'+directory1+args.File7

  filename1 = args.directory0+'/'+'%iMember%/'+directory1+args.File1
  filename2 = args.directory0+'/'+'%iMember%/'+directory1+args.File2
  filename3 = args.directory0+'/'+'%iMember%/'+directory1+args.File3
  filename4 = args.directory0+'/'+'%iMember%/'+directory1+args.File4
  filename5 = args.directory0+'/'+'%iMember%/'+directory1+args.File5
  filename6 = args.directory0+'/'+'%iMember%/'+directory1+args.File6
  filename7 = args.directory0+'/'+'%iMember%/'+directory1+args.File7


  # Modified to include multiple time files, currently 3 times for 3 h window 
  membersTemplate = \
'''
members from template:
  template:
    states:
    - state variables: *stvars
      date: '''+args.Date1+'''
      filename: '''+filename1+'''
    - state variables: *stvars
      date: '''+args.Date2+'''
      filename: '''+filename2+'''
    - state variables: *stvars
      date: '''+args.Date3+'''
      filename: '''+filename3+'''
    - state variables: *stvars
      date: '''+args.Date4+'''
      filename: '''+filename4+'''
    - state variables: *stvars
      date: '''+args.Date5+'''
      filename: '''+filename5+'''
    - state variables: *stvars
      date: '''+args.Date6+'''
      filename: '''+filename6+'''
    - state variables: *stvars
      date: '''+args.Date7+'''
      filename: '''+filename7+'''
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

if __name__ == '__main__': substituteEnsembleB_4d_7slots()
