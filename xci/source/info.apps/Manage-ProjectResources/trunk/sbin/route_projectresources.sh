#!/bin/bash
PYTHON=/soft/python-2.7.11/bin/python
export PYTHON
export LD_LIBRARY_PATH=/soft/python-2.7.11/lib
export PYTHONPATH=/soft/warehouse-1.0/PROD/django_xsede_warehouse
export DJANGO_CONF=/soft/warehouse-1.0/conf/settings_info_mgmt.conf
export DJANGO_SETTINGS_MODULE=xsede_warehouse.settings
$PYTHON /soft/warehouse-apps-1.0/Manage-ProjectResources/PROD/sbin/route_projectresources.py
