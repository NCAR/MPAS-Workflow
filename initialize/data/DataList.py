#!/usr/bin/env python3

'''
 (C) Copyright 2023 UCAR

 This software is licensed under the terms of the Apache Licence Version 2.0
 which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
'''

# copied from https://stackoverflow.com/questions/3487434/overriding-append-method-after-inheriting-from-a-python-list

import collections

class DataList(list, collections.MutableSequence):
    def __init__(self, check_method, iterator_arg=None):
        self.__check_method = check_method
        if not iterator_arg is None:
            self.extend(iterator_arg) # This validates the arguments...

    def insert(self, i, v):
        return super(DataList, self).insert(i, self.__check_method(v))

    def append(self, v):
        return super(DataList, self).append(self.__check_method(v))

    def extend(self, t):
        return super(DataList, self).extend([ self.__check_method(v) for v in t ])

    def __add__(self, t): # This is for something like `DataList(validator, [1, 2, 3]) + list([4, 5, 6])`...
        return super(DataList, self).__add__([ self.__check_method(v) for v in t ])

    def __iadd__(self, t): # This is for something like `l = DataList(validator); l += [1, 2, 3]`
        return super(DataList, self).__iadd__([ self.__check_method(v) for v in t ])

    def __setitem__(self, i, v):
        if isinstance(i, slice):
            return super(DataList, self).__setitem__(i, [ self.__check_method(v1) for v1 in v ]) # Extended slice...
        else:
            return super(DataList, self).__setitem__(i, self.__check_method(v))

    def __setslice__(self, i, j, t): # NOTE: extended slices use __setitem__, passing in a tuple for i
        return super(DataList, self).__setslice__(i, j, [ self.__check_method(v) for v in t ])
