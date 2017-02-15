#!/usr/bin/env python

import pprint
import os
import pwd
import re
import sys
import argparse
import logging
import logging.handlers
import signal
import datetime
from datetime import datetime, tzinfo, timedelta
from time import sleep
import httplib
import json
import csv
import ssl
import shutil

import django
django.setup()
from django.utils.dateparse import parse_datetime
from projectresources.models import *
from django.core import serializers

def fieldlist(arg):
    retval=""
    for d in arg:
        c=d+"="+'"'+arg[d]+'"'
        retval+= c+","
    return retval[:-1]

#default_file = '/Users/blau/endpoint_descriptions/trunk/apps/RouteProjectResources/projectresources.csv'
default_file = '/soft/warehouse-1.0/PROD/apps/RouteProjectResources/projectresources.csv'
#snarfing the whole database is not the way to do it, for this anyway)
with open(default_file, 'r') as my_file:
    csv_source_file = csv.DictReader(my_file)
    for row in csv_source_file:
        InDBAlready = ProjectResource.objects.filter(**row)
        if not InDBAlready:
            objtoserialize={}
            objtoserialize["model"]="projectresources.projectresource"
            objtoserialize["pk"]=None
            objtoserialize["fields"]=row
            jsonobj = json.dumps([objtoserialize])
            modelobjects =serializers.deserialize("json", jsonobj)

            for obj in modelobjects:
                obj.save()
