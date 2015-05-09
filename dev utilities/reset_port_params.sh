#!/bin/bash

# THIS SCRIPT SHOULD BE RUN ON AN ARRAY, NOT YOUR VM!

csxHelper="csx_cli.x -o execute -n csx_helper -- -o"
envSet="$csxHelper env_set"
envGet="$csxHelper env_get"
envUnset="$csxHelper env_unset"
envDump="$csxHelper env_dump"

defaultVal="REG_SZ@{[*]J(@,UNC,?)}"

function die() {
	echo $*
	exit 1
}

function setRegValue() {
	key="$1"
	value="$2"
	$envSet -N "$key" -V "$value"
}

function getRegValue() {
	key="$1"
	$envGet -N "$key"
}

function unsetRegValue() {
	key="$1"
	$envUnset -N "$key"
}


function clearPortParams() {
	for entry in `$envDump | grep PortParam | grep -v -E 'Instance|BOOT|BE_NORM' | cut -d'=' -f1`
	do
		echo "Unsetting registry key <$entry>"
		unsetRegValue "$entry"
	
		if [[ "$?" != 0 ]]; then
			die "Failed to clear <$entry"
		fi
	done
}

function resetDefault() {
	nextPortParam=`$envDump | grep PortParam | grep -v -E 'Instance' | cut -d'=' -f1 | wc -l`

	echo "Reseting default to PortParam${nextPortParam}"
	setRegValue "/SYSTEM/CurrentControlSet/services/cpd/Parameters/Device/PortParams${nextPortParam}" "$defaultVal"

	if [[ "$?" != 0 ]]; then
		die "Failed to reset default PortParam${nextPortParam}"
	fi
}

# Start execution

clearPortParams
resetDefault

# root@l5f42-1-spb spb:~> csx_cli.x -o execute -n csx_helper -- -o env_dump | grep PortParam | grep -v Instance
# /SYSTEM/CurrentControlSet/services/cpd/Parameters/Device/PortParams0=REG_SZ@{[52.0.0] J(saspmc,BOOT,0)}
# /system/CurrentControlSet/Services/CPD/Parameters/Device/PortParams1=REG_SZ@{[52.0.1] J(saspmc,BE_NORM,1)}
# /system/CurrentControlSet/Services/CPD/Parameters/Device/PortParams2=REG_SZ@{[36.0.0] J(iscsicsx,FE_SPECIAL,0)}
# /system/CurrentControlSet/Services/CPD/Parameters/Device/PortParams3=REG_SZ@{[36.0.1] J(iscsicsx,FE_NORM,1)}
# /system/CurrentControlSet/Services/CPD/Parameters/Device/PortParams4=REG_SZ@{[36.0.2] J(iscsicsx,FE_NORM,2)}
# /system/CurrentControlSet/Services/CPD/Parameters/Device/PortParams5=REG_SZ@{[36.0.3] J(iscsicsx,FE_NORM,3)}
# /system/CurrentControlSet/Services/CPD/Parameters/Device/PortParams6=REG_SZ@{[3.0.0] J(iscsicsx,FE_SPECIAL,4)}
# /system/CurrentControlSet/Services/CPD/Parameters/Device/PortParams7=REG_SZ@{[3.0.1] J(iscsicsx,FE_NORM,5)}
# /system/CurrentControlSet/Services/CPD/Parameters/Device/PortParams8=REG_SZ@{[5.0.0] J(iscsicsx,FE_NORM,6)}
# /system/CurrentControlSet/Services/CPD/Parameters/Device/PortParams9=REG_SZ@{[5.0.1] J(iscsicsx,FE_NORM,7)}
# /system/CurrentControlSet/Services/CPD/Parameters/Device/PortParams10=REG_SZ@{[*]J(@,UNC,?)}

