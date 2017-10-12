#!/bin/bash
MY_ROOT=/soft/warehouse-apps-1.0/Manage-ProjectResources/PROD
WAREHOUSE_ROOT=/soft/warehouse-1.0/PROD
PYTHON=/soft/python-current/bin/python
export LD_LIBRARY_PATH=/soft/python-current/lib/

export PYTHONPATH=${WAREHOUSE_ROOT}/django_xsede_warehouse
export DJANGO_CONF=/soft/warehouse-1.0/conf/settings_info_mgmt.conf
export DJANGO_SETTINGS_MODULE=xsede_warehouse.settings

${PYTHON} ${MY_ROOT}/sbin/route_projectresources.py ${@:1}
