#!/bin/bash

echo "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"
echo
echo "MR4 Persistence DB Consistency Check and recovery Script"
echo "=========================================================="

echo "The following DELETE queries clear CIMNAS tables associated with UAS tables."
echo

psql -d uemcpdb -U uem_cp_usr -c "DELETE FROM uem_cp.cimnas_filesystem;"

psql -d uemcpdb -U uem_cp_usr -c "DELETE FROM uem_cp.cimnas_iscsilun;"

psql -d uemcpdb -U uem_cp_usr -c "DELETE FROM uem_cp.cimnas_checkpoint;"

psql -d uemcpdb -U uem_cp_usr -c "DELETE FROM uem_cp.cimnas_iscsisnap;"

psql -d uemcpdb -U uem_cp_usr -c "DELETE FROM uem_cp.cimnas_export;"

psql -d uemcpdb -U uem_cp_usr -c "DELETE FROM uem_cp.cimnas_share;"

