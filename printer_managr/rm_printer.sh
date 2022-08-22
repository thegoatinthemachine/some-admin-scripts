#!/usr/bin/env bash

#Title: rm printer
#purpose: what it says on the tin, remove a printer
#version: 2020-10-22-10
#Author: Stewart Johnston



if [[ -z "${PRINTER_QUEUE}" ]]; then
	echo "Environment variable PRINTER_QUEUE empty, exiting\n";
	exit 1;
fi

lpadmin -x "${PRINTER_QUEUE}"

#Explanation
#lpadmin -x "${PRINTER_QUEUE}"
# -x instead of -p removes a print queue
