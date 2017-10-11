#!/bin/bash
PYTHON_ROOT=/soft/python-current
export PYTHON_EXEC=${PYTHON_ROOT}/bin/python
export LD_LIBRARY_PATH=${PYTHON_ROOT}/lib
export PYTHONPATH=/soft/warehouse-1.0/PROD/django_xsede_warehouse
export DJANGO_CONF=/soft/warehouse-1.0/conf/settings_info_mgmt.conf
export DJANGO_SETTINGS_MODULE=xsede_warehouse.settings
$PYTHON_EXEC /soft/warehouse-apps-1.0/Manage-ProjectResources/PROD/sbin/route_projectresources.py ${@:1}
