#!/bin/bash

#Title: add printer
#purpose: what it says on the tin, using cups print server and ippeverywhere
#version: 2021-09-29-13
#Author: Stewart Johnston

test_statement="printer ${PRINTER_QUEUE} is idle"

lpstat_result=$(lpstat -p ${PRINTER_QUEUE})
if [[ "$(echo ${lpstat_result} | cut -c 1-${#test_statement})" != "${test_statement}" ]];
    then
        echo "No printer found, go ahead. Result: $(echo ${lpstat_result} | cut -c 1-${#test_statement})";
    else
        echo "Printer found, no go";
        exit 0;
fi

#ENVIRONMENT VARIABLES NEEDED
if [[ -z "${PRINTER_QUEUE}" || \
 -z "${SERVER}" || \
 -z "${SERVER_PRINT_QUEUE}" || \
 -z "${USER_FACING_NAME}" || \
 -z "${LOCATION}" ]]; then
	echo "One or more Environment Variables missing; check that these exist \
in the environment: PRINTER_QUEUE SERVER SERVER_PRINT_QUEUE USER_FACING_NAME \
LOCATION\n";
	exit 1;
fi;

if nc -z ${SERVER} 631 2>/dev/null; then
    echo "${SERVER} found"
else
    echo "${SERVER} not found, exiting"
    exit 1;
fi

set -x;

lpadmin -E \
	-p "${PRINTER_QUEUE}" \
	-v ipps://"${SERVER}"/printers/"${SERVER_PRINT_QUEUE}" \
	-E \
	-D "${USER_FACING_NAME}" \
	-L "${LOCATION}" \
	-m everywhere \
	-o printer-is-shared=false \
	-o sides=two-sided-long-edge \
	-o cupsIPPSupplies=true \
	-o cupsSNMPSupplies=true
	
lpadmin_status=$?;
	
set +x;

echo "The status of lpadmin command is ${lpadmin_status}";

#Explanation
#lpadmin -E \ #Enables encryption
#	-p "${PRINTER_QUEUE}" \ #backend name for this print queue
#	_v ipps://"${SERVER}"/printers/"${SERVER_PRINT_QUEUE}" \ #device URI
#	-E \ #Enable and accept jobs
#	-D "${USER_FACING_NAME}" \ #What the user sees in the printer selection
#	#menus
#	-L "${LOCATION}" \ #What it says on the tin
#	-m everywhere \ # Use IPPeverywhere setup to talk along ipp with the
#	#print server instead of attempting to distribute or wrangle a ppd
#	-o printer-is-shared=false \ # MacOS will complain in the UI about this
#	#otherwise. Besides, we don't need it
#	-o sides=two-sided-long-edge \ #This _should_ enable two sided printing
#	#on any printers which support it. If they don't support it, it's a
#	#no-op, so there's not a lot of reason not to include this
#	-o cupsIPPSupplies=true \ #This might not do anything atm, but if I can
#	#get supplies to work, this and/or SNMP supplies will report toner/paper
#	#low shit, for example
#	-o cupsSNMPSupplies=true
