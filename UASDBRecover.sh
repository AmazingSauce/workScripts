#!/bin/bash

echo "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"
echo
echo "MR4 Persistence DB Consistency Check and recovery Script"
echo "=========================================================="

echo "The following UPDATE queries recover association table internal DB-generated 'id' reference integrity. The recovering is based on reference integrity by 'InstanceID' and 'InstanceName' columns. If this 'InstanceID' and 'InstanceName' reference integrity is valid then UPDATE queries can be used to recover DB-generated 'id' reference integrity. Particularly, UPDATE queries can be applied after deletion of CIMNAS table's content."
echo

echo -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
echo "31. NAS file systems associated either with UAS file systems or with UAS Storage volumes"
echo
echo "NASFilesystem 1:1 ----- UASFileSystemIdentityAssocLeaf, UASStorageFolumeFSIdentityAssocLeaf -----> 1:1 UASFileSystem || UASStorageVolume"
echo
echo "Restores integer keys using InstanceName keys"
echo Can be used if there are Non-associated NAS Shares by internal integer keys and no Non-associated NAS Shares by InstanceName keys
psql -d uemcpdb -U uem_cp_usr -c "UPDATE uem_cp.emc_uem_uasfilesystemidentityassocleaf AS ASSC SET systemelementid = NFS.id, sameelementid = FS.id FROM uem_cp.cimnas_filesystem AS NFS, uem_cp.emc_uem_uasfilesystemleaf AS FS WHERE ASSC.sameelementinstancename = TEXTCAT('root/emc:EMC_UEM_UASFileSystemLeaf%InstanceID=', FS.InstanceID) AND ASSC.systemelementinstancename = TEXTCAT('emc/cimnas:CIMNAS_Filesystem%id=', CAST(NFS.nas_id AS TEXT));"
echo
echo "Restores integer keys using InstanceName keys"
echo Can be used if there are Non-associated NAS Shares by internal integer keys and no Non-associated NAS Shares by InstanceName keys
psql -d uemcpdb -U uem_cp_usr -c "UPDATE uem_cp.emc_uem_uasstoragevolumefsidentityassocleaf AS ASSC SET systemelementid = NFS.id, sameelementid = SV.id FROM uem_cp.cimnas_filesystem AS NFS, uem_cp.emc_uem_uasstoragevolumeleaf AS SV WHERE ASSC.sameelementinstancename = TEXTCAT('root/emc:EMC_UEM_UASStorageVolumeLeaf%InstanceID=', SV.InstanceID) AND ASSC.systemelementinstancename = TEXTCAT('emc/cimnas:CIMNAS_Filesystem%id=', CAST(NFS.nas_id AS TEXT));"
echo


echo -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
echo "32. NAS iSCSI Luns associated with UAS Storage volumes"
echo
echo "NASiSCSILun 1:1 ---- UASStorageVolumeIdentityAssocLeaf ----- > 1:1 UASStorageVolume"
echo
echo "Restores integer keys using InstanceName keys"
echo Can be used if there are Non-associated NAS Shares by internal integer keys and no Non-associated NAS Shares by InstanceName keys
psql -d uemcpdb -U uem_cp_usr -c "UPDATE uem_cp.emc_uem_uasstoragevolumeidentityassocleaf  AS ASSC SET systemelementid = LUN.id, sameelementid = SV.id FROM uem_cp.emc_uem_uasstoragevolumeleaf AS SV, uem_cp.cimnas_iscsilun AS LUN WHERE ASSC.sameelementinstancename = TEXTCAT('root/emc:EMC_UEM_UASStorageVolumeLeaf%InstanceID=', SV.InstanceID) AND ASSC.systemelementinstancename = TEXTCAT(TEXTCAT(TEXTCAT(TEXTCAT(TEXTCAT('emc/cimnas:CIMNAS_iSCSILun%mover=', LUN.mover), '%number='), CAST(LUN.number AS TEXT)), '%target='), LUN.target);"
echo

echo -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
echo "33. NAS checkpoints associated with UAS file system snaps"
echo
echo "NASCheckpoint 1:1 ---- UASFileSystemSnapIdentityAssocLeaf -----> 1:1 UASFileSystemSnap"
echo
echo "Restores integer keys using InstanceName keys"
echo Can be used if there are Non-associated NAS Shares by internal integer keys and no Non-associated NAS Shares by InstanceName keys
psql -d uemcpdb -U uem_cp_usr -c "UPDATE uem_cp.emc_uem_uasfilesystemsnapidentityassocleaf AS ASSC SET systemelementid = CK.id, sameelementid = FSN.id FROM uem_cp.emc_uem_uasfilesystemsnapleaf AS FSN, uem_cp.cimnas_checkpoint AS CK WHERE ASSC.sameelementinstancename = TEXTCAT('root/emc:EMC_UEM_UASFileSystemSnapLeaf%InstanceID=', FSN.InstanceID) AND ASSC.systemelementinstancename = TEXTCAT('emc/cimnas:CIMNAS_Checkpoint%id=', CAST(CK.nas_id AS TEXT));"
echo

echo -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
echo "34. NAS iSCSI snaps associated with UAS storage volume snaps"
echo 
echo "NASiSCSISnap 1:1 ---- UASStorageVolumeSnapIdentityAssocLeaf -----> 1:1 UASStorageVolumeSnap"
echo
echo "Restores integer keys using InstanceName keys"
echo Can be used if there are Non-associated NAS Shares by internal integer keys and no Non-associated NAS Shares by InstanceName keys
psql -d uemcpdb -U uem_cp_usr -c "UPDATE uem_cp.emc_uem_uasstoragevolumesnapidentityassocleaf AS ASSC SET systemelementid = ISS.id, sameelementid = SVSN.id FROM uem_cp.emc_uem_uasstoragevolumesnapleaf AS SVSN, uem_cp.cimnas_iscsisnap AS ISS WHERE ASSC.sameelementinstancename = TEXTCAT('root/emc:EMC_UEM_UASStorageVolumeSnapLeaf%InstanceID=', SVSN.InstanceID) AND ASSC.systemelementinstancename = TEXTCAT(TEXTCAT(TEXTCAT('emc/cimnas:CIMNAS_iSCSISnap%id=', ISS.nas_id), '%mover='), ISS.mover);"
echo


echo -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
echo "35. NAS exports associated with UAS NFS share"
echo
echo "NASExport 1:1 ---- UASNFSShareIdentityAssocLeaf -----> 1:1 UASNFSShare"
echo
echo "Restores integer keys using InstanceName keys"
echo Can be used if there are Non-associated NAS Shares by internal integer keys and no Non-associated NAS Shares by InstanceName keys
psql -d uemcpdb -U uem_cp_usr -c "UPDATE uem_cp.emc_uem_uasnfsshareidentityassocleaf AS ASSC SET systemelementid = NE.id, sameelementid = US.id FROM uem_cp.emc_uem_uasnfsshareleaf AS US, uem_cp.cimnas_export AS NE WHERE ASSC.sameelementinstancename = TEXTCAT('root/emc:EMC_UEM_UASNFSShareLeaf%InstanceID=', US.InstanceID) AND ASSC.systemelementinstancename = TEXTCAT(TEXTCAT(TEXTCAT('emc/cimnas:CIMNAS_Export%mover=', NE.mover), '%path='), NE.path);"
echo  


echo -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
echo "36. NAS shares associated with UAS CIFS shares"
echo
echo "NASShare 1:1 ---- UASCIFSShareIdentityAssocLeaf ----- > 1:1 UASCIFSShare"
echo
echo "Restores integer keys using InstanceName keys"
echo Can be used if there are Non-associated NAS Shares by internal integer keys and no Non-associated NAS Shares by InstanceName keys
psql -d uemcpdb -U uem_cp_usr -c "UPDATE uem_cp.emc_uem_uascifsshareidentityassocleaf AS ASSC SET systemelementid = CS.id, sameelementid = US.id FROM uem_cp.emc_uem_uascifsshareleaf AS US, uem_cp.cimnas_share AS CS WHERE ASSC.sameelementinstancename = TEXTCAT('root/emc:EMC_UEM_UASCIFSShareLeaf%InstanceID=', US.InstanceID) AND ASSC.systemelementinstancename = TEXTCAT(TEXTCAT(TEXTCAT(TEXTCAT(TEXTCAT('emc/cimnas:CIMNAS_Share%mover=', CS.mover), '%name='), CS.name), '%server='), CS.server);"
echo






