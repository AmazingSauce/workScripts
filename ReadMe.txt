==============================================================================
SnmpTrapGen v1.1 - SNMP Trap Generator
==============================================================================

Copyright (C) 2010 SnmpSoft Company. All Rights Reserved.

Contents
--------
  1. Overview
  2. Features
  3. Usage & Parameters
  4. Examples
  5. License & Disclaimer
  6. Version History


1. Overview
------------
  SNMP is a  standard  protocol  for  network  devices  monitoring  and 
  management.  Almost all active network devices support SNMP.  Besides 
  that, SNMP is supported by many network applications and the majority
  of operational systems. 

  SnmpTrapGen  is  a  command-line  tool  which  simplifies its  use in 
  scripts and allows you to automate a large number of every day system
  administrator actions.  This  tool supports  IPv4  and  modern  IPv6, 
  allowing   you  to  avoid  difficulties  when   you  upgrade  network 
  structures. Besides that, SnmpSet, along with supporting a version of
  the  SNMPv1/SNMPv2c  protocol  which  is not safe,  supports  a safer 
  version of SNMPv3.  This allows  you to avoid violations of corporate 
  safety policies in case you use it.


2. Features
------------
  + Support of SNMP v1/v2c and SNMPv3
  + Support of IPv4 and IPv6
  + Command line interface (CLI)
  + Allows for any type of SNMP variable
  + Various Auth. & Privacy protocols
  + Windows NT/2000/XP/2003/Vista/2008/7

  
3. Usage & Parameters
----------------------
  SnmpTrapGen.exe [-q] -r:host [-p:port] [-t:timeout] [-v:version]
       [-c:community] [-ei:engine_id] [-sn:sec_name] [-ap:auth_proto]
       [-aw:auth_passwd] [-pp:priv_proto] [-pw:priv_passwd] [-ce:cont_engine]
       [-cn:cont_name] [-vid:var_oid] [-vtp:var_type] [-val:var_value]
       [-del:char] -eo:ent_oid -to:trap_oid

   -q               Quiet mode (suppress header; print variable value only)
   -r:host          Name or network address (IPv4/IPv6) of remote host.
   -p:port          SNMP port number on remote host. Default: 162
   -t:timeout       SNMP timeout in seconds (1-600). Default: 5
   -v:version       SNMP version. Supported version: 1, 2c or 3. Default: 1
   -c:community     SNMP community string for SNMP v1/v2c. Default: public
   -ei:engine_id    Engine ID. Format: hexadecimal string. (SNMPv3).
   -sn:sec_name     SNMP security name for SNMPv3.
   -ap:auth_proto   Authentication protocol. Supported: MD5, SHA (SNMPv3).
   -aw:auth_passwd  Authentication password (SNMPv3).
   -pp:priv_proto   Privacy protocol. Supported: DES, IDEA, AES128, AES192,
                    AES256, 3DES (SNMPv3).
   -pw:priv_passwd  Privacy password (SNMPv3).
   -cn:cont_name    Context name. (SNMPv3)
   -ce:cont_engine  Context engine. Format: hexadecimal string. (SNMPv3)
   -to:trap_oid     Object ID (OID) of SNMP trap.
   -eo:ent_oid      Enterprise Object ID (OID).
   -vid:var_oid     Object IDs (OID) of one or multiple trap variables.
   -val:var_value   Value of one or multiple trap variables.
   -vtp:var_type    Type of trap variables. Supported: int,uint,str,hex,oid,ip
                    Default: str
   -del:char        Multiple variables delimiter for vid/vtp/val.
                    
                    
4. Examples
------------
  SnmpTrapGen.exe -r:10.0.0.1 -t:10 -c:"private" -to:.1.3.6.1.2.1.1.4.0
  SnmpTrapGen.exe -r:SnmpCollector -q -v:2c -p:10162 -to:.1.3.6.1.2.1.1.1.0


5. License & Disclaimer
------------------------
  FREE USE LICENSE. You  may install  and use  any number of copies
  of  this  SOFTWARE  on your  devices  free of  charge.  You  must
  distribute  a copy of  this license  within  ReadMe.txt file with
  any  copy of the SOFTWARE and  anyone to whom you  distribute the
  SOFTWARE is subject to this license.

  RESTRICTIONS.  You may not  reduce the SOFTWARE to human readable
  form,  reverse engineer,  de-compile,  disassemble, merge,  adapt,
  or modify the SOFTWARE, except  and only to  the extent that such
  activity is expressly permitted by applicable law notwithstanding
  this  limitation.  You may not rent, lease,  or lend the SOFTWARE.
  You may not use the SOFTWARE to perform any unauthorized transfer
  of  information,  such  as  copying  or  transferring  a  file in
  violation of a copyright, or for any illegal purpose.

  NO WARRANTIES.  To the maximum extent permitted by applicable law,
  SnmpSoft Company  expressly   disclaims  any  warranty  for  this
  SOFTWARE. The SOFTWARE and any related documentation are provided
  "as is" without warranty  of any kind,  either express or implied,
  including,   without  limitation,  the  implied   warranties   of
  merchantability  or fitness for a particular  purpose. The entire
  risk  arising out of use or performance  of the  SOFTWARE remains
  with you.


6. Version History
-------------------
  1.1  - Multiple variables within one SNMP trap

  1.0  - Initial release
  

SnmpSoft Company
================
Simple Network Monitoring Programs
http://www.snmpsoft.com
FreeTools for Network Administrators
http://www.snmpsoft.com/freetools/
  
======================================EOF=====================================