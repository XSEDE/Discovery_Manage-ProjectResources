#!/usr/bin/env python3

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
try:
    import http.client as httplib
except ImportError:
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
from processing_status.process import ProcessingActivity

def fieldlist(arg):
    retval=""
    for d in arg:
        c=d+"="+'"'+arg[d]+'"'
        retval+= c+","
    return retval[:-1]

class UTC(tzinfo):
    def utcoffset(self, dt):
        return timedelta(0)
    def tzname(self, dt):
        return 'UTC'
    def dst(self, dt):
        return timedelta(0)
utc = UTC()

#default_file = '/soft/warehouse-apps-1.0/Manage-ProjectResources/var/projectresources.csv'
#default_file = './projectresources.csv'
default_file = sys.argv[1]
#snarfing the whole database is not the way to do it, for this anyway)
databasestate = serializers.serialize("json", ProjectResource.objects.all())
dbstate = json.loads(databasestate)
dbhash = {}
for obj in dbstate:
    dbhash[str(obj['fields']['project_number'])+str(obj['fields']['ResourceID'])]=obj
with open(default_file, 'r') as my_file:
    csv_source_file = csv.DictReader(my_file)
    #Start ProcessActivity
    pa_application=os.path.basename(__file__)
    pa_function='main'
    pa_topic = 'ProjectResources'
    pa_id = pa_topic
    pa_about = 'xsede.org'
    pa = ProcessingActivity(pa_application, pa_function, pa_id , pa_topic, pa_about)
    for row in csv_source_file:
        #InDBAlready = ProjectResource.objects.filter(**row)
        #if not InDBAlready:
        if row['project_number']+row['ResourceID'] in dbhash.keys():
            dbhash.pop(row['project_number']+row['ResourceID'])
            #print len(dbhash.keys())
            #if row['project_number']+row['ResourceID'] in dbhash.keys():
            #    print "something is wrong"
        else:
        
            objtoserialize={}
            objtoserialize["model"]="projectresources.projectresource"
            objtoserialize["pk"]=None
            objtoserialize["fields"]=row
            jsonobj = json.dumps([objtoserialize])
            modelobjects =serializers.deserialize("json", jsonobj)

            for obj in modelobjects:
                obj.save()
        
    #print dbhash.keys()
    #print len(dbhash.keys())
    #delete leftover entries
    for key in dbhash.keys():
        #print dbhash[key]
        ProjectResource.objects.filter(pk=dbhash[key]['pk']).delete()
    
    pa.FinishActivity(0, "")
