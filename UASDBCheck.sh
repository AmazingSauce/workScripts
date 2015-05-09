#!/bin/bash

echo "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"
echo
echo "MR4 Persistence DB Consistency Check Script (1"
echo "========================================================== (1"
echo
echo "Check and Recover script consist of 38 sections. "
echo
echo "Each section deals with the one association table."
echo 
echo "Title of a sections expresses the association rule. Then follows association notation:"
echo 
echo "<Left object name> <Min number of left objects : Max number of left objects> --- <Association name > ---> <Right object name> <Min number of right objects : Max number of right objects>"
echo
echo "Read as: By the assiciation for each Left object there must be associated from minimum Right objects till maximum Right objects and for each right object there must be associated from minimum Left objects till maximum Left objects"
echo
echo "Then follows 2 or 3 SELECT queries"
echo
echo "    1st query checks association by internal DB-generated integer keys"
echo "    2nd query checks association by natural object instance name based keys"
echo "    3rd query check for existence of duplicate associations"
echo
echo "In case of association is consistent the result of query must have 0 rows."
echo
echo "In case of association is inconsistent the result will contain rows with 'id' or 'instanceID' columns of the Left object"
echo
echo "Sections 31-36 contains commented out UPDATE queries."
echo "These UPDATE queries recover association table internal DB-generated 'id' reference integrity. The recovering is based on reference integrity by 'InstanceID' and 'InstanceName' columns. If this 'InstanceID' and 'InstanceName' reference integrity is valid then UPDATE queries can be used to recover DB-generated 'id' reference integrity. Particularly, UPDATE queries can be applied after deletion of CIMNAS table's content."
echo
echo "Usage:"
echo "1) :~>psql -d uemcpdb -U uem_cp_usr -f <Script File Name>"
echo
echo "2) Run queries from psql terminal:"
echo "          :~>psql -d uemcpdb -U uem_cp_usr"
echo "Copy and pase query."
echo

echo "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"
echo "1. Applications associated with storage elements: file systems or storage volumes (1"
echo
echo "UASApplication 1:1 --- UASApplicationStorageElementAssocLeaf --> 0:N UASFileSystem, UASStorageVolume"
echo
echo "Applications not-associated neither with File systems nor with Storage volumes by iteger keys (Warning)"
echo
psql -d uemcpdb -U uem_cp_usr -c "SELECT id AS appid FROM uem_cp.emc_uem_uasapplicationleaf EXCEPT (SELECT appid FROM (SELECT APP.id AS appid, ASSC.id AS assocID, FS.id AS seid, COUNT(*) AS cnt FROM uem_cp.emc_uem_uasfilesystemleaf AS FS, uem_cp.emc_uem_uasapplicationstorageelementassocleaf AS ASSC, uem_cp.emc_uem_uasapplicationleaf AS APP WHERE ASSC.partcomponenttype = 'root/emc:EMC_UEM_UASFileSystemLeaf' AND FS.id = ASSC.partcomponentid AND APP.id = ASSC.groupcomponentid GROUP BY FS.id, ASSC.id, APP.id HAVING COUNT(*) = 1) AS foo UNION SELECT appid FROM (SELECT APP.id AS appid, ASSC.id AS assocID, SV.id AS seid, COUNT(*) AS cnt FROM uem_cp.emc_uem_uasstoragevolumeleaf AS SV, uem_cp.emc_uem_uasapplicationstorageelementassocleaf AS ASSC, uem_cp.emc_uem_uasapplicationleaf AS APP WHERE ASSC.partcomponenttype = 'root/emc:EMC_UEM_UASStorageVolumeLeaf' AND SV.id = ASSC.partcomponentid AND APP.id = ASSC.groupcomponentid GROUP BY SV.id, ASSC.id, APP.id HAVING COUNT(*) = 1 ORDER BY appid, seid) AS bar);"

echo

echo "Applications not-associated neither with File systems nor with Storage volumes by InstanceName keys (Warning)"
echo
psql -d uemcpdb -U uem_cp_usr -c "SELECT InstanceID AS Application_InstanceID FROM uem_cp.emc_uem_uasapplicationleaf EXCEPT (SELECT Application_InstanceID FROM (SELECT APP.InstanceID AS Application_InstanceID, ASSC.id AS assocID, FS.InstanceID AS StorageElement_InstanceID, COUNT(*) AS cnt FROM uem_cp.emc_uem_uasfilesystemleaf AS FS, uem_cp.emc_uem_uasapplicationstorageelementassocleaf AS ASSC, uem_cp.emc_uem_uasapplicationleaf AS APP WHERE ASSC.partcomponentinstancename = TEXTCAT('root/emc:EMC_UEM_UASFileSystemLeaf%InstanceID=', FS.InstanceID) AND ASSC.groupcomponentinstancename = TEXTCAT('root/emc:EMC_UEM_UASApplicationLeaf%InstanceID=', APP.InstanceID) GROUP BY FS.InstanceID, ASSC.id, APP.InstanceID HAVING COUNT(*) = 1 ORDER BY Application_InstanceID, StorageElement_InstanceID) AS foo UNION SELECT Application_InstanceID FROM (SELECT APP.InstanceID AS Application_InstanceID, ASSC.id AS assocID, SV.InstanceID AS StorageElement_InstanceID, COUNT(*) AS cnt FROM uem_cp.emc_uem_uasstoragevolumeleaf AS SV, uem_cp.emc_uem_uasapplicationstorageelementassocleaf AS ASSC, uem_cp.emc_uem_uasapplicationleaf AS APP WHERE ASSC.partcomponentinstancename = TEXTCAT('root/emc:EMC_UEM_UASStorageVolumeLeaf%InstanceID=', SV.InstanceID) AND ASSC.groupcomponentinstancename = TEXTCAT('root/emc:EMC_UEM_UASApplicationLeaf%InstanceID=', APP.InstanceID) GROUP BY SV.InstanceID, ASSC.id, APP.InstanceID HAVING COUNT(*) = 1 ORDER BY Application_InstanceID, StorageElement_InstanceID) AS bar);"

echo ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
echo "2. File systems associated with the only EMC_LocalStoragePool (1"
echo
echo "UASFileSystem 0:N --- UASAllocatedFromStoragePoolAssocLeaf ----> 1:1 EMC_LocalStoragePool"
echo
echo Non-associated File Systems by internal integer keys
echo
psql -d uemcpdb -U uem_cp_usr -c "SELECT id AS fsid FROM uem_cp.emc_uem_uasfilesystemleaf EXCEPT (SELECT fsid FROM (SELECT FS.id AS fsid, ASSC.id AS asscid, COUNT(*) AS cnt FROM uem_cp.emc_uem_uasfilesystemleaf AS FS, uem_cp.emc_uem_uasallocatedfromstoragepoolassocleaf AS ASSC WHERE FS.id = ASSC.dependentid AND ASSC.dependenttype = 'root/emc:EMC_UEM_UASFileSystemLeaf' GROUP BY FS.id, ASSC.id HAVING COUNT(*) = 1) AS foo );"
echo
echo Non-associated File Systems by InstanceName keys
echo
psql -d uemcpdb -U uem_cp_usr -c "SELECT InstanceID AS FileSystem_InstanceID FROM uem_cp.emc_uem_uasfilesystemleaf EXCEPT (SELECT FileSystem_InstanceID FROM (SELECT FS.InstanceID AS FileSystem_InstanceID, ASSC.antecedentinstancename AS StoragePool, COUNT(*) AS cnt FROM uem_cp.emc_uem_uasfilesystemleaf AS FS, uem_cp.emc_uem_uasallocatedfromstoragepoolassocleaf AS ASSC WHERE ASSC.dependentinstancename = TEXTCAT('root/emc:EMC_UEM_UASFileSystemLeaf%InstanceID=', FS.InstanceID) GROUP BY FS.InstanceID, ASSC.antecedentinstancename HAVING COUNT(*) = 1 ORDER BY FS.InstanceID) AS foo);"
echo
echo More than 1 association 
echo
psql -d uemcpdb -U uem_cp_usr -c "SELECT FileSystem_InstanceID, cnt AS Number_of_Associations FROM (SELECT FS.InstanceID AS FileSystem_InstanceID, ASSC.antecedentinstancename AS StoragePool, COUNT(*) AS cnt FROM uem_cp.emc_uem_uasfilesystemleaf AS FS, uem_cp.emc_uem_uasallocatedfromstoragepoolassocleaf AS ASSC WHERE ASSC.dependentinstancename = TEXTCAT('root/emc:EMC_UEM_UASFileSystemLeaf%InstanceID=', FS.InstanceID) GROUP BY FS.InstanceID, ASSC.antecedentinstancename HAVING COUNT(*) > 1 ORDER BY FS.InstanceID, cnt) AS foo;"
echo

echo "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"
echo "3. Storage volumes associated with the only EMC_LocalStoragePool (1"
echo
echo "UASStorageVolume 0:N --- UASAllocatedFromStoragePoolAssocLeaf ----> 1:1 EMC_LocalStoragePool"
echo
psql -d uemcpdb -U uem_cp_usr -c "SELECT id AS svid FROM uem_cp.emc_uem_uasstoragevolumeleaf EXCEPT (SELECT svid FROM (SELECT SV.id AS svid, ASSC.id AS asscid, COUNT(*) AS cnt FROM uem_cp.emc_uem_uasstoragevolumeleaf AS SV, uem_cp.emc_uem_uasallocatedfromstoragepoolassocleaf AS ASSC WHERE SV.id = ASSC.dependentid AND ASSC.dependenttype = 'root/emc:EMC_UEM_UASStorageVolumeLeaf' GROUP BY SV.id, ASSC.id HAVING COUNT(*) = 1) AS foo);"
echo
echo Non-associated Storage Volumes by InstanceName keys
echo
psql -d uemcpdb -U uem_cp_usr -c "SELECT InstanceID AS StorageVolume_InstanceID FROM uem_cp.emc_uem_uasstoragevolumeleaf EXCEPT (SELECT StorageVolume_InstanceID FROM (SELECT SV.InstanceID AS StorageVolume_InstanceID, ASSC.antecedentinstancename AS StoragePool, COUNT(*) AS cnt FROM uem_cp.emc_uem_uasstoragevolumeleaf AS SV, uem_cp.emc_uem_uasallocatedfromstoragepoolassocleaf AS ASSC WHERE ASSC.dependentinstancename = TEXTCAT('root/emc:EMC_UEM_UASStorageVolumeLeaf%InstanceID=', SV.InstanceID) GROUP BY SV.InstanceID, ASSC.antecedentinstancename HAVING COUNT(*) = 1 ORDER BY SV.InstanceID) AS foo);"
echo
echo More than 1 association
echo
psql -d uemcpdb -U uem_cp_usr -c "SELECT StorageVolume_InstanceID, cnt AS Number_of_Associations FROM (SELECT SV.InstanceID AS StorageVolume_InstanceID, ASSC.antecedentinstancename AS StoragePool, COUNT(*) AS cnt FROM uem_cp.emc_uem_uasstoragevolumeleaf AS SV, uem_cp.emc_uem_uasallocatedfromstoragepoolassocleaf AS ASSC WHERE ASSC.dependentinstancename = TEXTCAT('root/emc:EMC_UEM_UASStorageVolumeLeaf%InstanceID=', SV.InstanceID) GROUP BY SV.InstanceID, ASSC.antecedentinstancename HAVING COUNT(*) > 1 ORDER BY SV.InstanceID) AS foo;"
echo

echo ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
echo "4. File systems associated each with the only application (1"
echo
echo "UASFileSystem 0:N --- UASApplicationStorageElementAssocLeaf ----> 1:1 UASApplication"
echo
echo Non-associated File Systems by internal integer keys
echo
psql -d uemcpdb -U uem_cp_usr -c "SELECT id AS fsid FROM uem_cp.emc_uem_uasfilesystemleaf EXCEPT (SELECT fsid FROM (SELECT FS.id AS fsid, ASSC.id AS assocID, APP.id AS appID, COUNT(*) AS CNT FROM uem_cp.emc_uem_uasfilesystemleaf AS FS, uem_cp.emc_uem_uasapplicationstorageelementassocleaf AS ASSC, uem_cp.emc_uem_uasapplicationleaf AS APP WHERE ASSC.partcomponenttype = 'root/emc:EMC_UEM_UASFileSystemLeaf' AND FS.id = ASSC.partcomponentid AND APP.id = ASSC.groupcomponentid GROUP BY FS.id, ASSC.id, APP.id HAVING COUNT(*) = 1) AS fsids ORDER BY fsid);"
echo
echo Non-associated File Systems by InstanceName keys
echo
psql -d uemcpdb -U uem_cp_usr -c "SELECT InstanceID AS FileSystem_InstanceID FROM uem_cp.emc_uem_uasfilesystemleaf EXCEPT (SELECT FileSystem_InstanceID FROM (SELECT FS.InstanceID AS FileSystem_InstanceID, ASSC.id AS assocID, APP.InstanceID AS Application_InstanceID, COUNT(*) AS CNT FROM uem_cp.emc_uem_uasfilesystemleaf AS FS, uem_cp.emc_uem_uasapplicationstorageelementassocleaf AS ASSC, uem_cp.emc_uem_uasapplicationleaf AS APP WHERE ASSC.partcomponentinstancename = TEXTCAT('root/emc:EMC_UEM_UASFileSystemLeaf%InstanceID=', FS.InstanceID) AND ASSC.groupcomponentinstancename = TEXTCAT('root/emc:EMC_UEM_UASApplicationLeaf%InstanceID=', APP.InstanceID) GROUP BY FS.InstanceID, ASSC.id, APP.InstanceID HAVING COUNT(*) = 1) AS fooo ORDER BY FileSystem_InstanceID);"
echo
echo More than 1 association
echo
psql -d uemcpdb -U uem_cp_usr -c "SELECT FileSystem_InstanceID, cnt AS Number_of_Associations FROM (SELECT FS.InstanceID AS FileSystem_InstanceID, ASSC.id AS assocID, APP.InstanceID AS Application_InstanceID, COUNT(*) AS CNT FROM uem_cp.emc_uem_uasfilesystemleaf AS FS, uem_cp.emc_uem_uasapplicationstorageelementassocleaf AS ASSC, uem_cp.emc_uem_uasapplicationleaf AS APP WHERE ASSC.partcomponentinstancename = TEXTCAT('root/emc:EMC_UEM_UASFileSystemLeaf%InstanceID=', FS.InstanceID) AND ASSC.groupcomponentinstancename = TEXTCAT('root/emc:EMC_UEM_UASApplicationLeaf%InstanceID=', APP.InstanceID) GROUP BY FS.InstanceID, ASSC.id, APP.InstanceID HAVING COUNT(*) > 1) AS fooo;"
echo

echo -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
echo "5. Storage volumes associated each with the only application (1"
echo
echo "UASStorageVolume 0:N --- UASApplicationStorageElementAssocLeaf --> 1:1 UASApplication"
echo
echo Non-associated Storage Volumes by internal integer keys
echo
psql -d uemcpdb -U uem_cp_usr -c "SELECT id AS svid FROM uem_cp.emc_uem_uasstoragevolumeleaf EXCEPT (SELECT svid FROM (SELECT SV.id AS svid, ASSC.id AS assocID, APP.id AS appID, COUNT(*) AS CNT FROM uem_cp.emc_uem_uasstoragevolumeleaf AS SV, uem_cp.emc_uem_uasapplicationstorageelementassocleaf AS ASSC, uem_cp.emc_uem_uasapplicationleaf AS APP WHERE ASSC.partcomponenttype = 'root/emc:EMC_UEM_UASStorageVolumeLeaf' AND SV.id = ASSC.partcomponentid AND APP.id = ASSC.groupcomponentid GROUP BY SV.id, ASSC.id, APP.id HAVING COUNT(*) = 1) AS svids ORDER BY svid);"
echo
echo Non-associated Storage Volumes by InstanceName keys
echo
psql -d uemcpdb -U uem_cp_usr -c "SELECT InstanceID AS StorageVolume_InstanceID FROM uem_cp.emc_uem_uasstoragevolumeleaf EXCEPT (SELECT StorageVolume_InstanceID FROM (SELECT SV.InstanceID AS StorageVolume_InstanceID, ASSC.id AS assocID, APP.InstanceID AS application_InstanceID, COUNT(*) AS CNT FROM uem_cp.emc_uem_uasstoragevolumeleaf AS SV, uem_cp.emc_uem_uasapplicationstorageelementassocleaf AS ASSC, uem_cp.emc_uem_uasapplicationleaf AS APP WHERE ASSC.partcomponentinstancename = TEXTCAT('root/emc:EMC_UEM_UASStorageVolumeLeaf%InstanceID=', SV.InstanceID) AND ASSC.groupcomponentinstancename = TEXTCAT('root/emc:EMC_UEM_UASApplicationLeaf%InstanceID=', APP.InstanceID) GROUP BY SV.InstanceID, ASSC.id, APP.InstanceID HAVING COUNT(*) = 1) AS fooo ORDER BY StorageVolume_InstanceID);"
echo
echo More than 1 association
echo
psql -d uemcpdb -U uem_cp_usr -c "SELECT StorageVolume_InstanceID, cnt AS Number_of_Associations FROM (SELECT SV.InstanceID AS StorageVolume_InstanceID, ASSC.id AS assocID, APP.InstanceID AS application_InstanceID, COUNT(*) AS CNT FROM uem_cp.emc_uem_uasstoragevolumeleaf AS SV, uem_cp.emc_uem_uasapplicationstorageelementassocleaf AS ASSC, uem_cp.emc_uem_uasapplicationleaf AS APP WHERE ASSC.partcomponentinstancename = TEXTCAT('root/emc:EMC_UEM_UASStorageVolumeLeaf%InstanceID=', SV.InstanceID) AND ASSC.groupcomponentinstancename = TEXTCAT('root/emc:EMC_UEM_UASApplicationLeaf%InstanceID=', APP.InstanceID) GROUP BY SV.InstanceID, ASSC.id, APP.InstanceID HAVING COUNT(*) > 1) AS fooo;"
echo

echo -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
echo "6. Containers associated each with the only Application (1"
echo
echo "UASContainer 0:N --- UASApplicationContainerAssocLeaf --> 1:1 UASApplication"
echo
echo Non-associated Containers by internal integer keys
echo
psql -d uemcpdb -U uem_cp_usr -c "SELECT id AS cid FROM uem_cp.emc_uem_uascontainerleaf EXCEPT (SELECT cid FROM (SELECT C.id AS cid, ASSC.id AS assocID, APP.id AS appID, COUNT(*) AS CNT FROM uem_cp.emc_uem_uascontainerleaf AS C, uem_cp.emc_uem_uasapplicationcontainerassocleaf AS ASSC, uem_cp.emc_uem_uasapplicationleaf AS APP WHERE C.id = ASSC.partcomponentid AND APP.id = ASSC.groupcomponentid GROUP BY C.id, ASSC.id, APP.id HAVING COUNT(*) = 1) AS svids ORDER BY cid);"
echo
echo Non-associated Containers by InstanceName keys
echo
psql -d uemcpdb -U uem_cp_usr -c "SELECT InstanceID AS container_InstanceID FROM uem_cp.emc_uem_uascontainerleaf EXCEPT (SELECT container_InstanceID FROM (SELECT C.instanceID AS container_InstanceID, ASSC.id AS assocID, APP.InstanceID AS application_InstanceID, COUNT(*) AS CNT FROM uem_cp.emc_uem_uascontainerleaf AS C, uem_cp.emc_uem_uasapplicationcontainerassocleaf AS ASSC, uem_cp.emc_uem_uasapplicationleaf AS APP WHERE ASSC.partcomponentinstancename = TEXTCAT('root/emc:EMC_UEM_UASContainerLeaf%InstanceID=', C.InstanceID) AND ASSC.groupcomponentinstancename = TEXTCAT('root/emc:EMC_UEM_UASApplicationLeaf%InstanceID=', APP.InstanceID) GROUP BY C.InstanceID, ASSC.id, APP.InstanceID HAVING COUNT(*) = 1) AS svids ORDER BY container_InstanceID);"
echo
echo More than 1 association
echo
psql -d uemcpdb -U uem_cp_usr -c "SELECT container_InstanceID, cnt AS Number_of_Associations FROM (SELECT C.instanceID AS container_InstanceID, ASSC.id AS assocID, APP.InstanceID AS application_InstanceID, COUNT(*) AS CNT FROM uem_cp.emc_uem_uascontainerleaf AS C, uem_cp.emc_uem_uasapplicationcontainerassocleaf AS ASSC, uem_cp.emc_uem_uasapplicationleaf AS APP WHERE ASSC.partcomponentinstancename = TEXTCAT('root/emc:EMC_UEM_UASContainerLeaf%InstanceID=', C.InstanceID) AND ASSC.groupcomponentinstancename = TEXTCAT('root/emc:EMC_UEM_UASApplicationLeaf%InstanceID=', APP.InstanceID) GROUP BY C.InstanceID, ASSC.id, APP.InstanceID HAVING COUNT(*) > 1) AS svids;"
echo

echo -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
echo "7. CIFS share objects associated either with File system or with file system snap (1"
echo
echo "UASCIFSShare 0:N --- UASFileSytemShareAssocLeaf || UASFileSytemSnapShareAssocLeaf ----> 1:1 UASFileSystem || UASFileSystemSnap"
echo
echo Non-associated UAS CIFS shares by internal integer keys
echo
psql -d uemcpdb -U uem_cp_usr -c "SELECT id AS shareID FROM uem_cp.emc_uem_uascifsshareleaf EXCEPT ((SELECT shareID FROM (SELECT SH.id AS shareID, ASSC.id AS assocID, FS.id AS fileSysID, COUNT(*) AS CNT FROM uem_cp.emc_uem_uascifsshareleaf AS SH, uem_cp.emc_uem_uasfilesystemshareassocleaf AS ASSC, uem_cp.emc_uem_uasfilesystemleaf AS FS WHERE ASSC.partcomponenttype = 'root/emc:EMC_UEM_UASCIFSShareLeaf' AND SH.id = ASSC.partcomponentid AND FS.id = ASSC.groupcomponentid GROUP BY SH.id, ASSC.id, FS.id HAVING COUNT(*) = 1) AS shids ORDER BY shareID) UNION (SELECT shareid FROM (SELECT SH.id AS shareID, ASSC.id AS assocID, FSNP.id AS fileSysID, COUNT(*) AS CNT FROM uem_cp.emc_uem_uascifsshareleaf AS SH, uem_cp.emc_uem_uasfilesystemsnapshareassocleaf AS ASSC, uem_cp.emc_uem_uasfilesystemsnapleaf AS FSNP WHERE ASSC.partcomponenttype = 'root/emc:EMC_UEM_UASCIFSShareLeaf' AND SH.id = ASSC.partcomponentid AND FSNP.id = ASSC.groupcomponentid GROUP BY SH.id, ASSC.id, FSNP.id HAVING COUNT(*) = 1) AS shsnps ORDER BY shareID));"
echo
echo Non-associated UAS CIFS shares by InstanceName keys
echo
psql -d uemcpdb -U uem_cp_usr -c "SELECT instanceID AS CIFSShare_InstanceID FROM uem_cp.emc_uem_uascifsshareleaf EXCEPT ((SELECT CIFSShare_InstanceID FROM (SELECT SH.InstanceID AS CIFSShare_InstanceID, ASSC.id AS assocID, FS.instanceID AS FileSystem_InstanceID, COUNT(*) AS CNT FROM uem_cp.emc_uem_uascifsshareleaf AS SH, uem_cp.emc_uem_uasfilesystemshareassocleaf AS ASSC, uem_cp.emc_uem_uasfilesystemleaf AS FS WHERE ASSC.partcomponentinstancename = TEXTCAT('root/emc:EMC_UEM_UASCIFSShareLeaf%InstanceID=', SH.InstanceID)  AND ASSC.groupcomponentinstancename = TEXTCAT('root/emc:EMC_UEM_UASFileSystemLeaf%InstanceID=', FS.InstanceID) GROUP BY SH.InstanceID, ASSC.id, FS.InstanceID HAVING COUNT(*) = 1) AS shids ORDER BY CIFSShare_InstanceID) UNION (SELECT CIFSShare_InstanceID FROM (SELECT SH.InstanceID AS CIFSShare_InstanceID, ASSC.id AS assocID, FSNP.InstanceID AS FileSystemSnap_InstanceID, COUNT(*) AS CNT FROM uem_cp.emc_uem_uascifsshareleaf AS SH, uem_cp.emc_uem_uasfilesystemsnapshareassocleaf AS ASSC, uem_cp.emc_uem_uasfilesystemsnapleaf AS FSNP WHERE ASSC.partcomponentinstancename = TEXTCAT('root/emc:EMC_UEM_UASCIFSShareLeaf%InstanceID=', SH.InstanceID)  AND ASSC.groupcomponentinstancename = TEXTCAT('root/emc:EMC_UEM_UASFileSystemSnapLeaf%InstanceID=', FSNP.InstanceID) GROUP BY SH.InstanceID, ASSC.id, FSNP.InstanceID HAVING COUNT(*) = 1) AS shsnps ORDER BY CIFSShare_InstanceID));"
echo
echo More than 1 association
echo
psql -d uemcpdb -U uem_cp_usr -c "((SELECT CIFSShare_InstanceID FROM (SELECT SH.InstanceID AS CIFSShare_InstanceID, ASSC.id AS assocID, FS.instanceID AS FileSystem_InstanceID, COUNT(*) AS CNT FROM uem_cp.emc_uem_uascifsshareleaf AS SH, uem_cp.emc_uem_uasfilesystemshareassocleaf AS ASSC, uem_cp.emc_uem_uasfilesystemleaf AS FS WHERE ASSC.partcomponentinstancename = TEXTCAT('root/emc:EMC_UEM_UASCIFSShareLeaf%InstanceID=', SH.InstanceID)  AND ASSC.groupcomponentinstancename = TEXTCAT('root/emc:EMC_UEM_UASFileSystemLeaf%InstanceID=', FS.InstanceID) GROUP BY SH.InstanceID, ASSC.id, FS.InstanceID HAVING COUNT(*) > 1) AS shids ORDER BY CIFSShare_InstanceID) UNION (SELECT CIFSShare_InstanceID FROM (SELECT SH.InstanceID AS CIFSShare_InstanceID, ASSC.id AS assocID, FSNP.InstanceID AS FileSystemSnap_InstanceID, COUNT(*) AS CNT FROM uem_cp.emc_uem_uascifsshareleaf AS SH, uem_cp.emc_uem_uasfilesystemsnapshareassocleaf AS ASSC, uem_cp.emc_uem_uasfilesystemsnapleaf AS FSNP WHERE ASSC.partcomponentinstancename = TEXTCAT('root/emc:EMC_UEM_UASCIFSShareLeaf%InstanceID=', SH.InstanceID)  AND ASSC.groupcomponentinstancename = TEXTCAT('root/emc:EMC_UEM_UASFileSystemSnapLeaf%InstanceID=', FSNP.InstanceID) GROUP BY SH.InstanceID, ASSC.id, FSNP.InstanceID HAVING COUNT(*) > 1) AS shsnps ORDER BY CIFSShare_InstanceID));"
echo

echo -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
echo "8. NFS share objects associated either with File system or with file system snap (1"
echo
echo "UASNFSShare 0:N --- UASFileSytemShareAssocLeaf || UASFileSytemSnapShareAssocLeaf ----> 1:1 UASFileSystem || UASFileSystemSnap"
echo
echo Non-associated UAS NFS shares by internal integer keys
echo
psql -d uemcpdb -U uem_cp_usr -c "SELECT id AS shareID FROM uem_cp.emc_uem_uasnfsshareleaf EXCEPT ((SELECT shareID FROM (SELECT SH.id AS shareID, ASSC.id AS assocID, FS.id AS fileSysID, COUNT(*) AS CNT FROM uem_cp.emc_uem_uasnfsshareleaf AS SH, uem_cp.emc_uem_uasfilesystemshareassocleaf AS ASSC, uem_cp.emc_uem_uasfilesystemleaf AS FS WHERE ASSC.partcomponenttype = 'root/emc:EMC_UEM_UASNFSShareLeaf' AND SH.id = ASSC.partcomponentid AND FS.id = ASSC.groupcomponentid GROUP BY SH.id, ASSC.id, FS.id HAVING COUNT(*) = 1) AS shids ORDER BY shareID) UNION (SELECT shareid FROM (SELECT SH.id AS shareID, ASSC.id AS assocID, FSNP.id AS fileSysID, COUNT(*) AS CNT FROM uem_cp.emc_uem_uasnfsshareleaf AS SH, uem_cp.emc_uem_uasfilesystemsnapshareassocleaf AS ASSC, uem_cp.emc_uem_uasfilesystemsnapleaf AS FSNP WHERE ASSC.partcomponenttype = 'root/emc:EMC_UEM_UASNFSShareLeaf' AND SH.id = ASSC.partcomponentid AND FSNP.id = ASSC.groupcomponentid GROUP BY SH.id, ASSC.id, FSNP.id HAVING COUNT(*) = 1) AS shsnps ORDER BY shareID));"
echo
echo Non-associated UAS NFS shares by InstanceName keys
echo
psql -d uemcpdb -U uem_cp_usr -c "SELECT instanceID AS NFSShare_InstanceID FROM uem_cp.emc_uem_uasnfsshareleaf EXCEPT ((SELECT NFSShare_InstanceID FROM (SELECT SH.InstanceID AS NFSShare_InstanceID, ASSC.id AS assocID, FS.instanceID AS FileSystem_InstanceID, COUNT(*) AS CNT FROM uem_cp.emc_uem_uasnfsshareleaf AS SH, uem_cp.emc_uem_uasfilesystemshareassocleaf AS ASSC, uem_cp.emc_uem_uasfilesystemleaf AS FS WHERE ASSC.partcomponentinstancename = TEXTCAT('root/emc:EMC_UEM_UASNFSShareLeaf%InstanceID=', SH.InstanceID)  AND ASSC.groupcomponentinstancename = TEXTCAT('root/emc:EMC_UEM_UASFileSystemLeaf%InstanceID=', FS.InstanceID) GROUP BY SH.InstanceID, ASSC.id, FS.InstanceID HAVING COUNT(*) = 1) AS shids ORDER BY NFSShare_InstanceID) UNION (SELECT NFSShare_InstanceID FROM (SELECT SH.InstanceID AS NFSShare_InstanceID, ASSC.id AS assocID, FSNP.InstanceID AS FileSystemSnap_InstanceID, COUNT(*) AS CNT FROM uem_cp.emc_uem_uasnfsshareleaf AS SH, uem_cp.emc_uem_uasfilesystemsnapshareassocleaf AS ASSC, uem_cp.emc_uem_uasfilesystemsnapleaf AS FSNP WHERE ASSC.partcomponentinstancename = TEXTCAT('root/emc:EMC_UEM_UASNFSShareLeaf%InstanceID=', SH.InstanceID)  AND ASSC.groupcomponentinstancename = TEXTCAT('root/emc:EMC_UEM_UASFileSystemSnapLeaf%InstanceID=', FSNP.InstanceID) GROUP BY SH.InstanceID, ASSC.id, FSNP.InstanceID HAVING COUNT(*) = 1) AS shsnps ORDER BY NFSShare_InstanceID));"
echo
echo More than 1 association
echo
psql -d uemcpdb -U uem_cp_usr -c "(SELECT NFSShare_InstanceID FROM (SELECT SH.InstanceID AS NFSShare_InstanceID, ASSC.id AS assocID, FS.instanceID AS FileSystem_InstanceID, COUNT(*) AS CNT FROM uem_cp.emc_uem_uasnfsshareleaf AS SH, uem_cp.emc_uem_uasfilesystemshareassocleaf AS ASSC, uem_cp.emc_uem_uasfilesystemleaf AS FS WHERE ASSC.partcomponentinstancename = TEXTCAT('root/emc:EMC_UEM_UASNFSShareLeaf%InstanceID=', SH.InstanceID)  AND ASSC.groupcomponentinstancename = TEXTCAT('root/emc:EMC_UEM_UASFileSystemLeaf%InstanceID=', FS.InstanceID) GROUP BY SH.InstanceID, ASSC.id, FS.InstanceID HAVING COUNT(*) > 1) AS shids ORDER BY NFSShare_InstanceID) UNION (SELECT NFSShare_InstanceID FROM (SELECT SH.InstanceID AS NFSShare_InstanceID, ASSC.id AS assocID, FSNP.InstanceID AS FileSystemSnap_InstanceID, COUNT(*) AS CNT FROM uem_cp.emc_uem_uasnfsshareleaf AS SH, uem_cp.emc_uem_uasfilesystemsnapshareassocleaf AS ASSC, uem_cp.emc_uem_uasfilesystemsnapleaf AS FSNP WHERE ASSC.partcomponentinstancename = TEXTCAT('root/emc:EMC_UEM_UASNFSShareLeaf%InstanceID=', SH.InstanceID)  AND ASSC.groupcomponentinstancename = TEXTCAT('root/emc:EMC_UEM_UASFileSystemSnapLeaf%InstanceID=', FSNP.InstanceID) GROUP BY SH.InstanceID, ASSC.id, FSNP.InstanceID HAVING COUNT(*) > 1) AS shsnps ORDER BY NFSShare_InstanceID);"
echo

echo -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
echo "9. No CIFS share object associated with both FS and FS snap (1"
echo
echo "UASCIFSShare 1 -------> 1 UASFileSystem  && 1 UASFileSystemSnap"
echo
echo Both-associated UAS CIFS shares by internal integer keys
echo
psql -d uemcpdb -U uem_cp_usr -c "(SELECT shareID FROM (SELECT SH.id AS shareID, ASSC.id AS assocID, FS.id AS fileSysID, COUNT(*) AS CNT FROM uem_cp.emc_uem_uascifsshareleaf AS SH, uem_cp.emc_uem_uasfilesystemshareassocleaf AS ASSC, uem_cp.emc_uem_uasfilesystemleaf AS FS WHERE ASSC.partcomponenttype = 'root/emc:EMC_UEM_UASCIFSShareLeaf' AND SH.id = ASSC.partcomponentid AND FS.id = ASSC.groupcomponentid GROUP BY SH.id, ASSC.id, FS.id HAVING COUNT(*) = 1) AS shids ORDER BY shareID) INTERSECT (SELECT shareid FROM (SELECT SH.id AS shareID, ASSC.id AS assocID, FSNP.id AS fileSysID, COUNT(*) AS CNT FROM uem_cp.emc_uem_uascifsshareleaf AS SH, uem_cp.emc_uem_uasfilesystemsnapshareassocleaf AS ASSC, uem_cp.emc_uem_uasfilesystemsnapleaf AS FSNP WHERE ASSC.partcomponenttype = 'root/emc:EMC_UEM_UASCIFSShareLeaf' AND  SH.id = ASSC.partcomponentid AND FSNP.id = ASSC.groupcomponentid GROUP BY SH.id, ASSC.id, FSNP.id HAVING COUNT(*) = 1) AS shsnps ORDER BY shareID);"
echo
echo Both-associated UAS NFS shares by InstanceName keys
echo
psql -d uemcpdb -U uem_cp_usr -c "(SELECT CIFSShare_InstanceID FROM (SELECT SH.InstanceID AS CIFSShare_InstanceID, ASSC.id AS assocID, FS.instanceID AS FileSystem_InstanceID, COUNT(*) AS CNT FROM uem_cp.emc_uem_uascifsshareleaf AS SH, uem_cp.emc_uem_uasfilesystemshareassocleaf AS ASSC, uem_cp.emc_uem_uasfilesystemleaf AS FS WHERE ASSC.partcomponentinstancename = TEXTCAT('root/emc:EMC_UEM_UASCIFSShareLeaf%InstanceID=', SH.InstanceID)  AND ASSC.groupcomponentinstancename = TEXTCAT('root/emc:EMC_UEM_UASFileSystemLeaf%InstanceID=', FS.InstanceID) GROUP BY SH.InstanceID, ASSC.id, FS.InstanceID HAVING COUNT(*) = 1) AS shids ORDER BY CIFSShare_InstanceID) INTERSECT (SELECT CIFSShare_InstanceID FROM (SELECT SH.InstanceID AS CIFSShare_InstanceID, ASSC.id AS assocID, FSNP.InstanceID AS FileSystemSnap_InstanceID, COUNT(*) AS CNT FROM uem_cp.emc_uem_uascifsshareleaf AS SH, uem_cp.emc_uem_uasfilesystemsnapshareassocleaf AS ASSC, uem_cp.emc_uem_uasfilesystemsnapleaf AS FSNP WHERE ASSC.partcomponentinstancename = TEXTCAT('root/emc:EMC_UEM_UASCIFSShareLeaf%InstanceID=', SH.InstanceID)  AND ASSC.groupcomponentinstancename = TEXTCAT('root/emc:EMC_UEM_UASFileSystemSnapLeaf%InstanceID=', FSNP.InstanceID) GROUP BY SH.InstanceID, ASSC.id, FSNP.InstanceID HAVING COUNT(*) = 1) AS shsnps ORDER BY CIFSShare_InstanceID)"
echo

echo -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
echo "10. No NFS share object associated with both FS and FS snap (1"
echo
echo "UASCIFSShare 0:N --- UASFileSytemShareAssocLeaf || UASFileSytemSnapShareAssocLeaf ----> 1:1 UASFileSystem || UASFileSystemSnap"
echo
echo Both-associated UAS CIFS shares by internal integer keys
echo
psql -d uemcpdb -U uem_cp_usr -c "(SELECT shareID FROM (SELECT SH.id AS shareID, ASSC.id AS assocID, FS.id AS fileSysID, COUNT(*) AS CNT FROM uem_cp.emc_uem_uascifsshareleaf AS SH, uem_cp.emc_uem_uasfilesystemshareassocleaf AS ASSC, uem_cp.emc_uem_uasfilesystemleaf AS FS WHERE ASSC.partcomponenttype = 'root/emc:EMC_UEM_UASCIFSShareLeaf' AND SH.id = ASSC.partcomponentid AND FS.id = ASSC.groupcomponentid GROUP BY SH.id, ASSC.id, FS.id HAVING COUNT(*) = 1) AS shids ORDER BY shareID) INTERSECT (SELECT shareid FROM (SELECT SH.id AS shareID, ASSC.id AS assocID, FSNP.id AS fileSysID, COUNT(*) AS CNT FROM uem_cp.emc_uem_uascifsshareleaf AS SH, uem_cp.emc_uem_uasfilesystemsnapshareassocleaf AS ASSC, uem_cp.emc_uem_uasfilesystemsnapleaf AS FSNP WHERE ASSC.partcomponenttype = 'root/emc:EMC_UEM_UASCIFSShareLeaf' AND  SH.id = ASSC.partcomponentid AND FSNP.id = ASSC.groupcomponentid GROUP BY SH.id, ASSC.id, FSNP.id HAVING COUNT(*) = 1) AS shsnps ORDER BY shareID);"
echo
echo Both-associated UAS NFS shares by InstanceName keys
echo
psql -d uemcpdb -U uem_cp_usr -c "(SELECT NFSShare_InstanceID FROM (SELECT SH.InstanceID AS NFSShare_InstanceID, ASSC.id AS assocID, FS.instanceID AS FileSystem_InstanceID, COUNT(*) AS CNT FROM uem_cp.emc_uem_uasnfsshareleaf AS SH, uem_cp.emc_uem_uasfilesystemshareassocleaf AS ASSC, uem_cp.emc_uem_uasfilesystemleaf AS FS WHERE ASSC.partcomponentinstancename = TEXTCAT('root/emc:EMC_UEM_UASNFSShareLeaf%InstanceID=', SH.InstanceID)  AND ASSC.groupcomponentinstancename = TEXTCAT('root/emc:EMC_UEM_UASFileSystemLeaf%InstanceID=', FS.InstanceID) GROUP BY SH.InstanceID, ASSC.id, FS.InstanceID HAVING COUNT(*) = 1) AS shids ORDER BY NFSShare_InstanceID) INTERSECT (SELECT NFSShare_InstanceID FROM (SELECT SH.InstanceID AS NFSShare_InstanceID, ASSC.id AS assocID, FSNP.InstanceID AS FileSystemSnap_InstanceID, COUNT(*) AS CNT FROM uem_cp.emc_uem_uasnfsshareleaf AS SH, uem_cp.emc_uem_uasfilesystemsnapshareassocleaf AS ASSC, uem_cp.emc_uem_uasfilesystemsnapleaf AS FSNP WHERE ASSC.partcomponentinstancename = TEXTCAT('root/emc:EMC_UEM_UASNFSShareLeaf%InstanceID=', SH.InstanceID)  AND ASSC.groupcomponentinstancename = TEXTCAT('root/emc:EMC_UEM_UASFileSystemSnapLeaf%InstanceID=', FSNP.InstanceID) GROUP BY SH.InstanceID, ASSC.id, FSNP.InstanceID HAVING COUNT(*) = 1) AS shsnps ORDER BY NFSShare_InstanceID);"
echo
echo -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
echo "11. Snap groups associated each with the only application (1"
echo
echo "UASSnapGroup 0:N ---- UASApplicationSnapDependencyAssocLeaf ---> 1:1 UASApplication"
echo
echo Non-associated Snap Groups by internal integer keys
echo
psql -d uemcpdb -U uem_cp_usr -c "SELECT id AS sgid FROM uem_cp.emc_uem_uassnapgroupleaf EXCEPT (SELECT DISTINCT sgid FROM (SELECT SG.id AS sgid, APP.id AS appid, ASSC.id AS asscid, COUNT(*) AS cnt FROM uem_cp.emc_uem_uassnapgroupleaf AS SG, uem_cp.emc_uem_uasapplicationleaf AS APP, uem_cp.emc_uem_uasapplicationsnapdependencyassocleaf AS ASSC WHERE APP.id = ASSC.antecedentid AND SG.id = ASSC.dependentid GROUP BY SG.id, APP.id, ASSC.id HAVING COUNT(*) = 1 ORDER BY SG.id) AS Foo);"
echo
echo Non-associated Snap Groups by InstanceName keys
echo
psql -d uemcpdb -U uem_cp_usr -c "SELECT InstanceID AS SnapGroup_InstanceID FROM uem_cp.emc_uem_uassnapgroupleaf EXCEPT (SELECT DISTINCT SnapGroup_InstanceID FROM (SELECT SG.InstanceID AS SnapGroup_InstanceID, APP.InstanceID AS Application_InstanceID, ASSC.id AS asscid, COUNT(*) AS cnt FROM uem_cp.emc_uem_uassnapgroupleaf AS SG, uem_cp.emc_uem_uasapplicationleaf AS APP, uem_cp.emc_uem_uasapplicationsnapdependencyassocleaf AS ASSC WHERE ASSC.antecedentinstancename = TEXTCAT('root/emc:EMC_UEM_UASApplicationLeaf%InstanceID=', APP.InstanceID) AND ASSC.dependentinstancename = TEXTCAT('root/emc:EMC_UEM_UASSnapGroupLeaf%InstanceID=', SG.InstanceID) GROUP BY SG.InstanceID, APP.InstanceID, ASSC.id HAVING COUNT(*) = 1 ORDER BY SG.InstanceID) AS Foo);"
echo
echo More than 1 association 
echo
psql -d uemcpdb -U uem_cp_usr -c "SELECT SnapGroup_InstanceID, cnt AS Number_of_Associations FROM (SELECT SG.InstanceID AS SnapGroup_InstanceID, APP.InstanceID AS Application_InstanceID, ASSC.id AS asscid, COUNT(*) AS cnt FROM uem_cp.emc_uem_uassnapgroupleaf AS SG, uem_cp.emc_uem_uasapplicationleaf AS APP, uem_cp.emc_uem_uasapplicationsnapdependencyassocleaf AS ASSC WHERE ASSC.antecedentinstancename = TEXTCAT('root/emc:EMC_UEM_UASApplicationLeaf%InstanceID=', APP.InstanceID) AND ASSC.dependentinstancename = TEXTCAT('root/emc:EMC_UEM_UASSnapGroupLeaf%InstanceID=', SG.InstanceID) GROUP BY SG.InstanceID, APP.InstanceID, ASSC.id HAVING COUNT(*) > 1 ORDER BY SG.InstanceID, cnt) AS Foo;"
echo
echo -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
echo "12. File system snaps assocated each with the only Snap group (1"
echo
echo "UASFileSystemSnap 0:N --- UASSnapGroupElementAssocLeaf ----> 1:1 UASSnapGroup"
echo
echo Non-associated File System Snaps by internal integer keys
psql -d uemcpdb -U uem_cp_usr -c "SELECT id AS fsnpid FROM uem_cp.emc_uem_uasfilesystemsnapleaf EXCEPT (SELECT fsnpid FROM (SELECT FSNP.id AS fsnpid, ASSC.id AS assocID, SG.id AS sgid, COUNT(*) AS CNT FROM uem_cp.emc_uem_uasfilesystemsnapleaf AS FSNP, uem_cp.emc_uem_uassnapgroupelementassocleaf AS ASSC, uem_cp.emc_uem_uassnapgroupleaf AS SG WHERE ASSC.partcomponenttype = 'root/emc:EMC_UEM_UASFileSystemSnapLeaf' AND FSNP.id = ASSC.partcomponentid AND SG.id = ASSC.groupcomponentid GROUP BY FSNP.id, ASSC.id, SG.id HAVING COUNT(*) = 1) AS fsids);"
echo
echo Non-associated File System Snaps by InstanceName keys
psql -d uemcpdb -U uem_cp_usr -c "SELECT InstanceID AS FileSystemSnap_InstanceID FROM uem_cp.emc_uem_uasfilesystemsnapleaf EXCEPT (SELECT FileSystemSnap_InstanceID FROM (SELECT FSNP.InstanceID AS FileSystemSnap_InstanceID, ASSC.id AS assocID, SG.InstanceID AS SnapGroup_InstanceID, COUNT(*) AS CNT FROM uem_cp.emc_uem_uasfilesystemsnapleaf AS FSNP, uem_cp.emc_uem_uassnapgroupelementassocleaf AS ASSC, uem_cp.emc_uem_uassnapgroupleaf AS SG WHERE ASSC.partcomponentinstancename = TEXTCAT('root/emc:EMC_UEM_UASFileSystemSnapLeaf%InstanceID=', FSNP.InstanceID) AND ASSC.groupcomponentinstancename = TEXTCAT('root/emc:EMC_UEM_UASSnapGroupLeaf%InstanceID=', SG.InstanceID) GROUP BY FSNP.InstanceID, ASSC.id, SG.InstanceID HAVING COUNT(*) = 1 ORDER BY FSNP.InstanceID) AS fsids);"
echo
echo More than 1 association 
psql -d uemcpdb -U uem_cp_usr -c "SELECT FileSystemSnap_InstanceID, cnt AS Number_of_Associations FROM (SELECT FSNP.InstanceID AS FileSystemSnap_InstanceID, ASSC.id AS assocID, SG.InstanceID AS SnapGroup_InstanceID, COUNT(*) AS CNT FROM uem_cp.emc_uem_uasfilesystemsnapleaf AS FSNP, uem_cp.emc_uem_uassnapgroupelementassocleaf AS ASSC, uem_cp.emc_uem_uassnapgroupleaf AS SG WHERE ASSC.partcomponentinstancename = TEXTCAT('root/emc:EMC_UEM_UASFileSystemSnapLeaf%InstanceID=', FSNP.InstanceID) AND ASSC.groupcomponentinstancename = TEXTCAT('root/emc:EMC_UEM_UASSnapGroupLeaf%InstanceID=', SG.InstanceID) GROUP BY FSNP.InstanceID, ASSC.id, SG.InstanceID HAVING COUNT(*) > 1 ORDER BY FSNP.InstanceID) AS fsids;"
echo
echo -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
echo "13. Storage volume snaps assocated each with the only Snap group (1"
echo
echo "UASStorageVolumeSnap 0:N --- UASSnapGroupElementAssocLeaf ----> 1:1 UASSnapGroup"
echo
echo Non-associated Storage Volume Snaps by internal integer keys
echo
psql -d uemcpdb -U uem_cp_usr -c "SELECT id AS svsnpid FROM uem_cp.emc_uem_uasstoragevolumesnapleaf EXCEPT (SELECT svsnpid FROM (SELECT SVSNP.id AS svsnpid, ASSC.id AS assocID, SG.id AS sgid, COUNT(*) AS CNT FROM uem_cp.emc_uem_uasstoragevolumesnapleaf AS SVSNP, uem_cp.emc_uem_uassnapgroupelementassocleaf AS ASSC, uem_cp.emc_uem_uassnapgroupleaf AS SG WHERE ASSC.partcomponenttype = 'root/emc:EMC_UEM_UASStorageVolumeSnapLeaf' AND SVSNP.id = ASSC.partcomponentid AND SG.id = ASSC.groupcomponentid GROUP BY SVSNP.id, ASSC.id, SG.id HAVING COUNT(*) = 1) AS svsids ORDER BY svsnpid);"
echo
echo Non-associated Storage Volume Snaps by InstanceName keys
echo
psql -d uemcpdb -U uem_cp_usr -c "SELECT InstanceID AS StorageVolumeSnap_InstanceID FROM uem_cp.emc_uem_uasstoragevolumesnapleaf EXCEPT (SELECT StorageVolumeSnap_InstanceID FROM (SELECT SVSNP.InstanceID AS StorageVolumeSnap_InstanceID, ASSC.id AS assocID, SG.InstanceID AS SnapGroup_InstanceID, COUNT(*) AS CNT FROM uem_cp.emc_uem_uasstoragevolumesnapleaf AS SVSNP, uem_cp.emc_uem_uassnapgroupelementassocleaf AS ASSC, uem_cp.emc_uem_uassnapgroupleaf AS SG WHERE ASSC.partcomponentinstancename = TEXTCAT('root/emc:EMC_UEM_UASStorageVolumeSnapLeaf%InstanceID=', SVSNP.InstanceID) AND ASSC.groupcomponentinstancename = TEXTCAT('root/emc:EMC_UEM_UASSnapGroupLeaf%InstanceID=', SG.InstanceID) GROUP BY SVSNP.InstanceID, ASSC.id, SG.InstanceID HAVING COUNT(*) = 1 ORDER BY SVSNP.InstanceID) AS svsids);"
echo
echo More than 1 association
echo
psql -d uemcpdb -U uem_cp_usr -c "SELECT StorageVolumeSnap_InstanceID, cnt AS Number_of_Associations FROM (SELECT SVSNP.InstanceID AS StorageVolumeSnap_InstanceID, ASSC.id AS assocID, SG.InstanceID AS SnapGroup_InstanceID, COUNT(*) AS CNT FROM uem_cp.emc_uem_uasstoragevolumesnapleaf AS SVSNP, uem_cp.emc_uem_uassnapgroupelementassocleaf AS ASSC, uem_cp.emc_uem_uassnapgroupleaf AS SG WHERE ASSC.partcomponentinstancename = TEXTCAT('root/emc:EMC_UEM_UASStorageVolumeSnapLeaf%InstanceID=', SVSNP.InstanceID) AND ASSC.groupcomponentinstancename = TEXTCAT('root/emc:EMC_UEM_UASSnapGroupLeaf%InstanceID=', SG.InstanceID) GROUP BY SVSNP.InstanceID, ASSC.id, SG.InstanceID HAVING COUNT(*) > 1 ORDER BY SVSNP.InstanceID, CNT) AS svsids;"
echo

echo -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
echo "14. File system snaps associated each with the only File system (1"
echo
echo "UASFileSystemSnap 0:N ---- UASFileSystemSnapDependencyAssocLeaf ---> 1:1 UASFileSystem"
echo
echo Non-associated File System Snaps by internal integer keys
echo
psql -d uemcpdb -U uem_cp_usr -c "SELECT id AS fsnpid FROM uem_cp.emc_uem_uasfilesystemsnapleaf EXCEPT (SELECT fsnpid FROM (SELECT FSNP.id AS fsnpid, ASSC.id AS assocID, FS.id AS fsid, COUNT(*) AS CNT FROM uem_cp.emc_uem_uasfilesystemsnapleaf AS FSNP, uem_cp.emc_uem_uasfilesystemsnapdependencyassocleaf AS ASSC, uem_cp.emc_uem_uasfilesystemleaf AS FS WHERE FSNP.id = ASSC.dependentid AND FS.id = ASSC.antecedentid GROUP BY FSNP.id, ASSC.id, FS.id HAVING COUNT(*) = 1) AS fsids ORDER BY fsnpid);"
echo
echo Non-associated File System Snaps by InstanceName keys
echo
psql -d uemcpdb -U uem_cp_usr -c "SELECT InstanceID AS FileSystemSnap_InstanceID FROM uem_cp.emc_uem_uasfilesystemsnapleaf EXCEPT (SELECT FileSystemSnap_InstanceID FROM (SELECT FSNP.InstanceID AS FileSystemSnap_InstanceID, ASSC.id AS assocID, FS.InstanceID AS FileSystem_InstanceID, COUNT(*) AS CNT FROM uem_cp.emc_uem_uasfilesystemsnapleaf AS FSNP, uem_cp.emc_uem_uasfilesystemsnapdependencyassocleaf AS ASSC, uem_cp.emc_uem_uasfilesystemleaf AS FS WHERE ASSC.dependentinstancename = TEXTCAT('root/emc:EMC_UEM_UASFileSystemSnapLeaf%InstanceID=', FSNP.InstanceID) AND ASSC.antecedentinstancename = TEXTCAT('root/emc:EMC_UEM_UASFileSystemLeaf%InstanceID=', FS.InstanceID) GROUP BY FSNP.InstanceID, ASSC.id, FS.InstanceID HAVING COUNT(*) = 1 ORDER BY FSNP.InstanceID) AS fsids);"
echo
echo More than 1 association 
echo
psql -d uemcpdb -U uem_cp_usr -c "SELECT FileSystemSnap_InstanceID, cnt AS Number_of_Associations FROM (SELECT FSNP.InstanceID AS FileSystemSnap_InstanceID, ASSC.id AS assocID, FS.InstanceID AS FileSystem_InstanceID, COUNT(*) AS CNT FROM uem_cp.emc_uem_uasfilesystemsnapleaf AS FSNP, uem_cp.emc_uem_uasfilesystemsnapdependencyassocleaf AS ASSC, uem_cp.emc_uem_uasfilesystemleaf AS FS WHERE ASSC.dependentinstancename = TEXTCAT('root/emc:EMC_UEM_UASFileSystemSnapLeaf%InstanceID=', FSNP.InstanceID) AND ASSC.antecedentinstancename = TEXTCAT('root/emc:EMC_UEM_UASFileSystemLeaf%InstanceID=', FS.InstanceID) GROUP BY FSNP.InstanceID, ASSC.id, FS.InstanceID HAVING COUNT(*) > 1 ORDER BY FSNP.InstanceID, CNT) AS fsids;"
echo

echo -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
echo "15. Storage volume snaps assocated each with the only Storage volume (1"
echo
echo "UASStorageVolumeSnap 0:N ---- UASStorageVolumeSnapDependencyAssocLeaf ---> 1:1 UASStorageVolume"
echo
echo Non-associated Storage Volume Snaps by internal integer keys
echo
psql -d uemcpdb -U uem_cp_usr -c "SELECT id AS svsnpid FROM uem_cp.emc_uem_uasstoragevolumesnapleaf EXCEPT (SELECT svsnpid FROM (SELECT SVSNP.id AS svsnpid, ASSC.id AS assocID, SV.id AS svid, COUNT(*) AS CNT FROM uem_cp.emc_uem_uasstoragevolumesnapleaf AS SVSNP, uem_cp.emc_uem_uasstoragevolumesnapdependencyassocleaf AS ASSC, uem_cp.emc_uem_uasstoragevolumeleaf AS SV WHERE SVSNP.id = ASSC.dependentid AND SV.id = ASSC.antecedentid GROUP BY SVSNP.id, ASSC.id, SV.id HAVING COUNT(*) = 1) AS fsids ORDER BY svsnpid);"
echo
echo Non-associated Storage Volume Snaps by InstanceName keys
echo
psql -d uemcpdb -U uem_cp_usr -c "SELECT InstanceID AS StorageVolumeSnap_InstanceID FROM uem_cp.emc_uem_uasstoragevolumesnapleaf EXCEPT (SELECT StorageVolumeSnap_InstanceID FROM (SELECT SVSNP.InstanceID AS StorageVolumeSnap_InstanceID, ASSC.id AS assocID, SV.InstanceID AS StorageVolume_InstanceID, COUNT(*) AS CNT FROM uem_cp.emc_uem_uasstoragevolumesnapleaf AS SVSNP, uem_cp.emc_uem_uasstoragevolumesnapdependencyassocleaf AS ASSC, uem_cp.emc_uem_uasstoragevolumeleaf AS SV WHERE ASSC.dependentinstancename = TEXTCAT('root/emc:EMC_UEM_UASStorageVolumeSnapLeaf%InstanceID=', SVSNP.InstanceID) AND ASSC.antecedentinstancename = TEXTCAT('root/emc:EMC_UEM_UASStorageVolumeLeaf%InstanceID=', SV.InstanceID) GROUP BY SVSNP.InstanceID, ASSC.id, SV.InstanceID HAVING COUNT(*) = 1 ORDER BY SVSNP.InstanceID) AS svsids);"
echo
echo More than 1 association 
echo
psql -d uemcpdb -U uem_cp_usr -c "SELECT StorageVolumeSnap_InstanceID, cnt AS Number_of_Associations FROM (SELECT SVSNP.InstanceID AS StorageVolumeSnap_InstanceID, ASSC.id AS assocID, SV.InstanceID AS StorageVolume_InstanceID, COUNT(*) AS CNT FROM uem_cp.emc_uem_uasstoragevolumesnapleaf AS SVSNP, uem_cp.emc_uem_uasstoragevolumesnapdependencyassocleaf AS ASSC, uem_cp.emc_uem_uasstoragevolumeleaf AS SV WHERE ASSC.dependentinstancename = TEXTCAT('root/emc:EMC_UEM_UASStorageVolumeSnapLeaf%InstanceID=', SVSNP.InstanceID) AND ASSC.antecedentinstancename = TEXTCAT('root/emc:EMC_UEM_UASStorageVolumeLeaf%InstanceID=', SV.InstanceID) GROUP BY SVSNP.InstanceID, ASSC.id, SV.InstanceID HAVING COUNT(*) > 1 ORDER BY SVSNP.InstanceID, CNT) AS svsids;"
echo
echo -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
echo "16. File systems associated each with the only NAS File system (1"
echo
echo "UASFileSystem 1:1 --- UASFileSystemIdentityAssocLeaf ----> 1:1 NASFilesystem"
echo
echo Non-associated File Systems by internal integer keys
psql -d uemcpdb -U uem_cp_usr -c "SELECT id AS fsid FROM uem_cp.emc_uem_uasfilesystemleaf EXCEPT (SELECT fsid FROM (SELECT FS.id AS fsid, ASSC.id AS assocID, NS.id AS nsid, COUNT(*) AS cnt FROM uem_cp.emc_uem_uasfilesystemleaf AS FS, uem_cp.emc_uem_uasfilesystemidentityassocleaf AS ASSC, uem_cp.cimnas_filesystem AS NS WHERE FS.id = ASSC.sameelementid AND NS.id = ASSC.systemelementid AND ASSC.sameelementtype = 'root/emc:EMC_UEM_UASFileSystemLeaf' GROUP BY FS.id, ASSC.id, NS.id HAVING COUNT(*) = 1 ORDER BY FS.id, NS.id) AS foo);"
echo
echo Non-associated File Systems by InstanceName keys
echo
psql -d uemcpdb -U uem_cp_usr -c "SELECT InstanceID AS FileSystem_InstanceID FROM uem_cp.emc_uem_uasfilesystemleaf EXCEPT (SELECT FileSystem_InstanceID FROM (SELECT FS.InstanceID AS FileSystem_InstanceID, ASSC.id AS assocID, NS.nas_id AS nas_id, COUNT(*) AS cnt FROM uem_cp.emc_uem_uasfilesystemleaf AS FS, uem_cp.emc_uem_uasfilesystemidentityassocleaf AS ASSC, uem_cp.cimnas_filesystem AS NS WHERE ASSC.sameelementinstancename = TEXTCAT('root/emc:EMC_UEM_UASFileSystemLeaf%InstanceID=', FS.InstanceID) AND ASSC.systemelementinstancename = TEXTCAT('emc/cimnas:CIMNAS_Filesystem%id=', CAST(NS.nas_id AS TEXT)) GROUP BY FS.InstanceID, ASSC.id, NS.nas_id HAVING COUNT(*) = 1 ORDER BY FS.InstanceID) AS foo);"
echo
echo More than 1 association 
echo
psql -d uemcpdb -U uem_cp_usr -c "SELECT FileSystem_InstanceID, cnt AS Number_of_Associations FROM (SELECT FS.InstanceID AS FileSystem_InstanceID, ASSC.id AS assocID, NS.nas_id AS nas_id, COUNT(*) AS cnt FROM uem_cp.emc_uem_uasfilesystemleaf AS FS, uem_cp.emc_uem_uasfilesystemidentityassocleaf AS ASSC, uem_cp.cimnas_filesystem AS NS WHERE ASSC.sameelementinstancename = TEXTCAT('root/emc:EMC_UEM_UASFileSystemLeaf%InstanceID=', FS.InstanceID) AND ASSC.systemelementinstancename = TEXTCAT('emc/cimnas:CIMNAS_Filesystem%id=', CAST(NS.nas_id AS TEXT)) GROUP BY FS.InstanceID, ASSC.id, NS.nas_id HAVING COUNT(*) > 1 ORDER BY FS.InstanceID, cnt) AS foo;"
echo
echo -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
echo "17. File systems have the only association with NAS File system (1"
echo
echo "UASFileSystem 1:1 --- UASFileSystemIdentityAssocLeaf --->"
echo
echo "Non-associated File Systems by internal integer keys"
psql -d uemcpdb -U uem_cp_usr -c "SELECT id AS fsid FROM uem_cp.emc_uem_uasfilesystemleaf EXCEPT (SELECT fsid FROM (SELECT FS.id AS fsid, ASSC.id AS assocID, COUNT(*) AS cnt FROM uem_cp.emc_uem_uasfilesystemleaf AS FS, uem_cp.emc_uem_uasfilesystemidentityassocleaf AS ASSC WHERE FS.id = ASSC.sameelementid AND ASSC.sameelementtype = 'root/emc:EMC_UEM_UASFileSystemLeaf' GROUP BY FS.id, ASSC.id HAVING COUNT(*) = 1 ORDER BY FS.id) AS foo);"
echo
echo Non-associated File Systems by InstanceName keys
echo
psql -d uemcpdb -U uem_cp_usr -c "SELECT InstanceID AS FileSystem_InstanceID FROM uem_cp.emc_uem_uasfilesystemleaf EXCEPT (SELECT FileSystem_InstanceID FROM (SELECT FS.InstanceID AS FileSystem_InstanceID, ASSC.id AS assocID, COUNT(*) AS cnt FROM uem_cp.emc_uem_uasfilesystemleaf AS FS, uem_cp.emc_uem_uasfilesystemidentityassocleaf AS ASSC WHERE ASSC.sameelementinstancename = TEXTCAT('root/emc:EMC_UEM_UASFileSystemLeaf%InstanceID=', FS.InstanceID) GROUP BY FS.InstanceID, ASSC.id HAVING COUNT(*) = 1 ORDER BY FS.InstanceID) AS foo);"
echo
echo More than 1 association
psql -d uemcpdb -U uem_cp_usr -c "SELECT FileSystem_InstanceID, cnt AS Number_of_Associations FROM (SELECT FS.InstanceID AS FileSystem_InstanceID, ASSC.id AS assocID, COUNT(*) AS cnt FROM uem_cp.emc_uem_uasfilesystemleaf AS FS, uem_cp.emc_uem_uasfilesystemidentityassocleaf AS ASSC WHERE ASSC.sameelementinstancename = TEXTCAT('root/emc:EMC_UEM_UASFileSystemLeaf%InstanceID=', FS.InstanceID) GROUP BY FS.InstanceID, ASSC.id HAVING COUNT(*) > 1 ORDER BY FS.InstanceID, cnt) AS foo;"
echo
echo -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
echo "18. Storage volumes associated each with the only NAS File system (1"
echo
echo "UASStorageVolume 1:1 --- UASStorageVolumeFSIdentityAssocLeaf ----> 1:1 NASFilesystem"
echo
echo Non-associated Storage Volumes by internal integer keys
psql -d uemcpdb -U uem_cp_usr -c "SELECT id AS svid FROM uem_cp.emc_uem_uasstoragevolumeleaf EXCEPT (SELECT svid FROM (SELECT SV.id AS svid, ASSC.id AS assocID, NS.id AS nsid, COUNT(*) AS cnt FROM uem_cp.emc_uem_uasstoragevolumeleaf AS SV, uem_cp.emc_uem_uasstoragevolumefsidentityassocleaf AS ASSC, uem_cp.cimnas_filesystem AS NS WHERE SV.id = ASSC.sameelementid AND NS.id = ASSC.systemelementid AND ASSC.sameelementtype = 'root/emc:EMC_UEM_UASStorageVolumeLeaf' GROUP BY SV.id, ASSC.id, NS.id HAVING COUNT(*) = 1 ORDER BY SV.id, NS.id) AS foo);"
echo
echo Non-associated Storage Volumes by InstanceName keys
psql -d uemcpdb -U uem_cp_usr -c "SELECT InstanceID AS StorageVolume_InstanceID FROM uem_cp.emc_uem_uasstoragevolumeleaf EXCEPT (SELECT StorageVolume_InstanceID FROM (SELECT SV.InstanceID AS StorageVolume_InstanceID, ASSC.id AS assocID, NS.nas_id AS nas_id, COUNT(*) AS cnt FROM uem_cp.emc_uem_uasstoragevolumeleaf AS SV, uem_cp.emc_uem_uasstoragevolumefsidentityassocleaf AS ASSC, uem_cp.cimnas_filesystem AS NS WHERE ASSC.sameelementinstancename = TEXTCAT('root/emc:EMC_UEM_UASStorageVolumeLeaf%InstanceID=', SV.InstanceID) AND ASSC.systemelementinstancename = TEXTCAT('emc/cimnas:CIMNAS_Filesystem%id=', CAST(NS.nas_id AS TEXT)) GROUP BY SV.InstanceID, ASSC.id, NS.nas_id HAVING COUNT(*) = 1 ORDER BY SV.InstanceID) AS foo);"
echo
echo More than with 1 associated
psql -d uemcpdb -U uem_cp_usr -c "SELECT StorageVolume_InstanceID, cnt AS Number_of_Associations FROM (SELECT SV.InstanceID AS StorageVolume_InstanceID, ASSC.id AS assocID, NS.nas_id AS nas_id, COUNT(*) AS cnt FROM uem_cp.emc_uem_uasstoragevolumeleaf AS SV, uem_cp.emc_uem_uasstoragevolumefsidentityassocleaf AS ASSC, uem_cp.cimnas_filesystem AS NS WHERE ASSC.sameelementinstancename = TEXTCAT('root/emc:EMC_UEM_UASStorageVolumeLeaf%InstanceID=', SV.InstanceID) AND ASSC.systemelementinstancename = TEXTCAT('emc/cimnas:CIMNAS_Filesystem%id=', CAST(NS.nas_id AS TEXT)) GROUP BY SV.InstanceID, ASSC.id, NS.nas_id HAVING COUNT(*) > 1 ORDER BY SV.InstanceID, cnt) AS foo;"
echo
echo -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
echo "19. Storage volumes have the only association with NAS File system (1"
echo
echo "UASStorageVolume 1:1 --- UASStorageVolumeFSIdentityAssocLeaf -->"
echo
echo "Non-associated Storage Volumes by internal integer keys"
psql -d uemcpdb -U uem_cp_usr -c "SELECT id AS svid FROM uem_cp.emc_uem_uasstoragevolumeleaf EXCEPT (SELECT svid FROM (SELECT SV.id AS svid, ASSC.id AS assocID, COUNT(*) AS cnt FROM uem_cp.emc_uem_uasstoragevolumeleaf AS SV, uem_cp.emc_uem_uasstoragevolumefsidentityassocleaf AS ASSC WHERE SV.id = ASSC.sameelementid AND ASSC.sameelementtype = 'root/emc:EMC_UEM_UASStorageVolumeLeaf' GROUP BY SV.id, ASSC.id HAVING COUNT(*) = 1 ORDER BY SV.id) AS foo);"
echo
echo Non-associated File Systems by InstanceName keys
psql -d uemcpdb -U uem_cp_usr -c "SELECT InstanceID AS StorageVolume_InstanceID FROM uem_cp.emc_uem_uasstoragevolumeleaf EXCEPT (SELECT StorageVolume_InstanceID FROM (SELECT SV.InstanceID AS StorageVolume_InstanceID, ASSC.id AS assocID, COUNT(*) AS cnt FROM uem_cp.emc_uem_uasstoragevolumeleaf AS SV, uem_cp.emc_uem_uasstoragevolumefsidentityassocleaf AS ASSC WHERE ASSC.sameelementinstancename = TEXTCAT('root/emc:EMC_UEM_UASStorageVolumeLeaf%InstanceID=', SV.InstanceID) GROUP BY SV.InstanceID, ASSC.id HAVING COUNT(*) = 1 ORDER BY SV.InstanceID) AS foo);"
echo
echo More than 1 association
psql -d uemcpdb -U uem_cp_usr -c "SELECT StorageVolume_InstanceID, cnt AS Number_of_Associations FROM (SELECT SV.InstanceID AS StorageVolume_InstanceID, ASSC.id AS assocID, COUNT(*) AS cnt FROM uem_cp.emc_uem_uasstoragevolumeleaf AS SV, uem_cp.emc_uem_uasstoragevolumefsidentityassocleaf AS ASSC WHERE ASSC.sameelementinstancename = TEXTCAT('root/emc:EMC_UEM_UASStorageVolumeLeaf%InstanceID=', SV.InstanceID) GROUP BY SV.InstanceID, ASSC.id HAVING COUNT(*) > 1 ORDER BY SV.InstanceID, cnt) AS foo;"
echo

echo -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
echo "20. Storage volumes associated each with the only NAS iSCSI LUN (1"
echo
echo "UASStorageVolume 1:1 --- UASStorageVolumeIdentityAssocLeaf ----> 1:1 NASiSCSILun"
echo
echo Non-associated Storage Volumes by internal integer keys
psql -d uemcpdb -U uem_cp_usr -c "SELECT id AS svid FROM uem_cp.emc_uem_uasstoragevolumeleaf EXCEPT (SELECT svid FROM (SELECT SV.id AS svid, ASSC.id AS assocID, LUN.id AS lid, COUNT(*) AS cnt FROM uem_cp.emc_uem_uasstoragevolumeleaf AS SV, uem_cp.emc_uem_uasstoragevolumeidentityassocleaf AS ASSC, uem_cp.cimnas_iscsilun AS LUN WHERE SV.id = ASSC.sameelementid AND LUN.id = ASSC.systemelementid AND ASSC.sameelementtype = 'root/emc:EMC_UEM_UASStorageVolumeLeaf' GROUP BY SV.id, ASSC.id, LUN.id HAVING COUNT(*) = 1 ORDER BY SV.id, LUN.id) AS foo);"
echo
echo Non-associated Storage Volumes by InstanceName keys
psql -d uemcpdb -U uem_cp_usr -c "SELECT InstanceID AS StorageVolume_InstanceID FROM uem_cp.emc_uem_uasstoragevolumeleaf EXCEPT (SELECT StorageVolume_InstanceID FROM (SELECT SV.InstanceID AS StorageVolume_InstanceID, ASSC.id AS assocID, LUN.mover AS LUN_mover, LUN.number AS LUN_number, LUN.target AS LUN_target, COUNT(*) AS cnt FROM uem_cp.emc_uem_uasstoragevolumeleaf AS SV, uem_cp.emc_uem_uasstoragevolumeidentityassocleaf AS ASSC, uem_cp.cimnas_iscsilun AS LUN WHERE ASSC.sameelementinstancename = TEXTCAT('root/emc:EMC_UEM_UASStorageVolumeLeaf%InstanceID=', SV.InstanceID) AND ASSC.systemelementinstancename = TEXTCAT(TEXTCAT(TEXTCAT(TEXTCAT(TEXTCAT('emc/cimnas:CIMNAS_iSCSILun%mover=', LUN.mover), '%number='), CAST(LUN.number AS TEXT)), '%target='), LUN.target) GROUP BY SV.InstanceID, ASSC.id, LUN.mover, LUN.number, LUN.target HAVING COUNT(*) = 1 ORDER BY SV.InstanceID) AS foo);"
echo
echo More than with 1 associated
psql -d uemcpdb -U uem_cp_usr -c "SELECT StorageVolume_InstanceID, cnt AS Number_of_Associations FROM (SELECT SV.InstanceID AS StorageVolume_InstanceID, ASSC.id AS assocID, LUN.mover AS LUN_mover, LUN.number AS LUN_number, LUN.target AS LUN_target, COUNT(*) AS cnt FROM uem_cp.emc_uem_uasstoragevolumeleaf AS SV, uem_cp.emc_uem_uasstoragevolumeidentityassocleaf AS ASSC, uem_cp.cimnas_iscsilun AS LUN WHERE ASSC.sameelementinstancename = TEXTCAT('root/emc:EMC_UEM_UASStorageVolumeLeaf%InstanceID=', SV.InstanceID) AND ASSC.systemelementinstancename = TEXTCAT(TEXTCAT(TEXTCAT(TEXTCAT(TEXTCAT('emc/cimnas:CIMNAS_iSCSILun%mover=', LUN.mover), '%number='), CAST(LUN.number AS TEXT)), '%target='), LUN.target) GROUP BY SV.InstanceID, ASSC.id, LUN.mover, LUN.number, LUN.target HAVING COUNT(*) > 1 ORDER BY SV.InstanceID, cnt) AS foo;"
echo


echo -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
echo "21. Storage volumes have the only association with NAS iSCSI LUN (1"
echo 
echo "UASStorageVolume 1:1 --- UASStorageVolumeIdentityAssocLeaf ---->"
echo
echo Non-associated Storage Volumes by internal integer keys
psql -d uemcpdb -U uem_cp_usr -c "SELECT id AS svid FROM uem_cp.emc_uem_uasstoragevolumeleaf EXCEPT (SELECT svid FROM (SELECT SV.id AS svid, ASSC.id AS assocID, COUNT(*) AS cnt FROM uem_cp.emc_uem_uasstoragevolumeleaf AS SV, uem_cp.emc_uem_uasstoragevolumeidentityassocleaf AS ASSC WHERE SV.id = ASSC.sameelementid AND ASSC.sameelementtype = 'root/emc:EMC_UEM_UASStorageVolumeLeaf' GROUP BY SV.id, ASSC.id HAVING COUNT(*) = 1 ORDER BY SV.id) AS foo);"
echo
echo Non-associated Storage Volumes by InstanceName keys
psql -d uemcpdb -U uem_cp_usr -c "SELECT InstanceID AS StorageVolume_InstanceID FROM uem_cp.emc_uem_uasstoragevolumeleaf EXCEPT (SELECT StorageVolume_InstanceID FROM (SELECT SV.InstanceID AS StorageVolume_InstanceID, ASSC.id AS assocID, COUNT(*) AS cnt FROM uem_cp.emc_uem_uasstoragevolumeleaf AS SV, uem_cp.emc_uem_uasstoragevolumeidentityassocleaf AS ASSC WHERE ASSC.sameelementinstancename = TEXTCAT('root/emc:EMC_UEM_UASStorageVolumeLeaf%InstanceID=', SV.InstanceID) GROUP BY SV.InstanceID, ASSC.id HAVING COUNT(*) = 1 ORDER BY SV.InstanceID) AS foo);"
echo
echo More than 1 association
psql -d uemcpdb -U uem_cp_usr -c "SELECT StorageVolume_InstanceID, cnt AS Number_of_Associations FROM (SELECT SV.InstanceID AS StorageVolume_InstanceID, ASSC.id AS assocID, COUNT(*) AS cnt FROM uem_cp.emc_uem_uasstoragevolumeleaf AS SV, uem_cp.emc_uem_uasstoragevolumeidentityassocleaf AS ASSC WHERE ASSC.sameelementinstancename = TEXTCAT('root/emc:EMC_UEM_UASStorageVolumeLeaf%InstanceID=', SV.InstanceID) GROUP BY SV.InstanceID, ASSC.id HAVING COUNT(*) > 1 ORDER BY SV.InstanceID, cnt) AS foo;"
echo

echo -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
echo "22. NFS share objects associated each with the only NAS export (1"
echo
echo "UASNFSShare 1:1 --- UASNFSShareIdentityAssocLeaf ----> 1:1 NASExport"
echo
echo Non-associated NFS Shares by internal integer keys
psql -d uemcpdb -U uem_cp_usr -c "SELECT id AS shareid FROM uem_cp.emc_uem_uasnfsshareleaf EXCEPT (SELECT shareid FROM (SELECT US.id AS shareid, ASSC.id AS assocID, NE.id AS expid, COUNT(*) AS cnt FROM uem_cp.emc_uem_uasnfsshareleaf AS US, uem_cp.emc_uem_uasnfsshareidentityassocleaf AS ASSC, uem_cp.cimnas_export AS NE WHERE US.id = ASSC.sameelementid AND NE.id = ASSC.systemelementid AND ASSC.sameelementtype = 'root/emc:EMC_UEM_UASNFSShareLeaf' GROUP BY US.id, ASSC.id, NE.id HAVING COUNT(*) = 1 ORDER BY US.id, NE.id) AS foo);"
echo
echo Non-associated NFS Shares by InstanceName keys
psql -d uemcpdb -U uem_cp_usr -c "SELECT InstanceID AS NFSShare_InstanceID FROM uem_cp.emc_uem_uasnfsshareleaf EXCEPT (SELECT NFSShare_InstanceID FROM (SELECT US.InstanceID AS NFSShare_InstanceID, ASSC.id AS assocID, NE.mover AS NASExport_mover, NE.path AS NASExport_path, COUNT(*) AS cnt FROM uem_cp.emc_uem_uasnfsshareleaf AS US, uem_cp.emc_uem_uasnfsshareidentityassocleaf AS ASSC, uem_cp.cimnas_export AS NE WHERE ASSC.sameelementinstancename = TEXTCAT('root/emc:EMC_UEM_UASNFSShareLeaf%InstanceID=', US.InstanceID) AND ASSC.systemelementinstancename = TEXTCAT(TEXTCAT(TEXTCAT('emc/cimnas:CIMNAS_Export%mover=', NE.mover), '%path='), NE.path) GROUP BY US.InstanceID, ASSC.id, NE.mover, NE.path HAVING COUNT(*) = 1 ORDER BY US.InstanceID) AS foo);"
echo
echo More than 1 associated
psql -d uemcpdb -U uem_cp_usr -c "SELECT NFSShare_InstanceID, cnt AS Number_of_Associations FROM (SELECT US.InstanceID AS NFSShare_InstanceID, ASSC.id AS assocID, NE.mover AS NASExport_mover, NE.path AS NASExport_path, COUNT(*) AS cnt FROM uem_cp.emc_uem_uasnfsshareleaf AS US, uem_cp.emc_uem_uasnfsshareidentityassocleaf AS ASSC, uem_cp.cimnas_export AS NE WHERE ASSC.sameelementinstancename = TEXTCAT('root/emc:EMC_UEM_UASNFSShareLeaf%InstanceID=', US.InstanceID) AND ASSC.systemelementinstancename = TEXTCAT(TEXTCAT(TEXTCAT('emc/cimnas:CIMNAS_Export%mover=', NE.mover), '%path='), NE.path) GROUP BY US.InstanceID, ASSC.id, NE.mover, NE.path HAVING COUNT(*) > 1 ORDER BY US.InstanceID, cnt) AS foo;"
echo


echo -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
echo "23. NFS share objects have each with the only association with NAS export (1"
echo
echo "UASNFSShare 1:1 --- UASNFSShareIdentityAssocLeaf ---->"
echo
echo Non-associated NFS Shares by internal integer keys
psql -d uemcpdb -U uem_cp_usr -c "SELECT id AS shareid FROM uem_cp.emc_uem_uasnfsshareleaf EXCEPT (SELECT shareid FROM (SELECT US.id AS shareid, ASSC.id AS assocID, COUNT(*) AS cnt FROM uem_cp.emc_uem_uasnfsshareleaf AS US, uem_cp.emc_uem_uasnfsshareidentityassocleaf AS ASSC WHERE US.id = ASSC.sameelementid AND ASSC.sameelementtype = 'root/emc:EMC_UEM_UASNFSShareLeaf' GROUP BY US.id, ASSC.id HAVING COUNT(*) = 1 ORDER BY US.id) AS foo);"
echo
echo Non-associated NFS Shares by InstanceName keys
psql -d uemcpdb -U uem_cp_usr -c "SELECT InstanceID AS NFSShare_InstanceID FROM uem_cp.emc_uem_uasnfsshareleaf EXCEPT (SELECT NFSShare_InstanceID FROM (SELECT US.InstanceID AS NFSShare_InstanceID, ASSC.id AS assocID, COUNT(*) AS cnt FROM uem_cp.emc_uem_uasnfsshareleaf AS US, uem_cp.emc_uem_uasnfsshareidentityassocleaf AS ASSC WHERE ASSC.sameelementinstancename = TEXTCAT('root/emc:EMC_UEM_UASNFSShareLeaf%InstanceID=', US.InstanceID) GROUP BY US.InstanceID, ASSC.id HAVING COUNT(*) = 1 ORDER BY US.InstanceID) AS foo);"
echo
echo More than 1 association
psql -d uemcpdb -U uem_cp_usr -c "SELECT NFSShare_InstanceID, cnt AS Number_of_Associations FROM (SELECT US.InstanceID AS NFSShare_InstanceID, ASSC.id AS assocID, COUNT(*) AS cnt FROM uem_cp.emc_uem_uasnfsshareleaf AS US, uem_cp.emc_uem_uasnfsshareidentityassocleaf AS ASSC WHERE ASSC.sameelementinstancename = TEXTCAT('root/emc:EMC_UEM_UASNFSShareLeaf%InstanceID=', US.InstanceID) GROUP BY US.InstanceID, ASSC.id HAVING COUNT(*) > 1 ORDER BY US.InstanceID) AS foo;"
echo

echo -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
echo "24. CIFS share objects associated each with the only NAS share (1"
echo
echo "UASCIFSShare 1:1 --- UASNFSShareIdentityAssocLeaf ----> 1:1 NASShare"
echo
echo Non-associated CIFS Shares by internal integer keys
psql -d uemcpdb -U uem_cp_usr -c "SELECT id AS shareid FROM uem_cp.emc_uem_uascifsshareleaf EXCEPT (SELECT shareid FROM (SELECT US.id AS shareid, ASSC.id AS assocID, NE.id AS expid, COUNT(*) AS cnt FROM uem_cp.emc_uem_uascifsshareleaf AS US, uem_cp.emc_uem_uascifsshareidentityassocleaf AS ASSC, uem_cp.cimnas_share AS NE WHERE US.id = ASSC.sameelementid AND NE.id = ASSC.systemelementid AND ASSC.sameelementtype = 'root/emc:EMC_UEM_UASCIFSShareLeaf' GROUP BY US.id, ASSC.id, NE.id HAVING COUNT(*) = 1 ORDER BY US.id, NE.id) AS foo);"
echo
echo Non-associated CIFS Shares by InstanceName keys
psql -d uemcpdb -U uem_cp_usr -c "SELECT InstanceID AS CIFSShare_InstanceID FROM uem_cp.emc_uem_uascifsshareleaf EXCEPT (SELECT CIFSShare_InstanceID FROM (SELECT US.InstanceID AS CIFSShare_InstanceID, ASSC.id AS assocID, CS.mover AS Share_mover, CS.name AS Share_name, CS.server AS Share_CIFSServer, COUNT(*) AS cnt FROM uem_cp.emc_uem_uascifsshareleaf AS US, uem_cp.emc_uem_uascifsshareidentityassocleaf AS ASSC, uem_cp.cimnas_share AS CS WHERE ASSC.sameelementinstancename = TEXTCAT('root/emc:EMC_UEM_UASCIFSShareLeaf%InstanceID=', US.InstanceID) AND ASSC.systemelementinstancename = TEXTCAT(TEXTCAT(TEXTCAT(TEXTCAT(TEXTCAT('emc/cimnas:CIMNAS_Share%mover=', CS.mover), '%name='), CS.name), '%server='), CS.server) GROUP BY US.InstanceID, ASSC.id, CS.mover, CS.name, CS.server HAVING COUNT(*) = 1 ORDER BY US.InstanceID) AS foo);"
echo
echo More than 1 association
psql -d uemcpdb -U uem_cp_usr -c "SELECT CIFSShare_InstanceID, cnt AS Number_of_Associations FROM (SELECT US.InstanceID AS CIFSShare_InstanceID, ASSC.id AS assocID, CS.mover AS Share_mover, CS.name AS Share_name, CS.server AS Share_CIFSServer, COUNT(*) AS cnt FROM uem_cp.emc_uem_uascifsshareleaf AS US, uem_cp.emc_uem_uascifsshareidentityassocleaf AS ASSC, uem_cp.cimnas_share AS CS WHERE ASSC.sameelementinstancename = TEXTCAT('root/emc:EMC_UEM_UASCIFSShareLeaf%InstanceID=', US.InstanceID) AND ASSC.systemelementinstancename = TEXTCAT(TEXTCAT(TEXTCAT(TEXTCAT(TEXTCAT('emc/cimnas:CIMNAS_Share%mover=', CS.mover), '%name='), CS.name), '%server='), CS.server) GROUP BY US.InstanceID, ASSC.id, CS.mover, CS.name, CS.server HAVING COUNT(*) > 1 ORDER BY US.InstanceID) AS foo;"
echo

echo -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
echo "25. CIFS share objects have each with the only association with NAS share (1"
echo
echo "UASCIFSShare 1:1 --- UASNFSShareIdentityAssocLeaf ----> 1:1"
echo
echo Non-associated CIFS Shares by internal integer keys
psql -d uemcpdb -U uem_cp_usr -c "SELECT id AS shareid FROM uem_cp.emc_uem_uascifsshareleaf EXCEPT (SELECT shareid FROM (SELECT US.id AS shareid, ASSC.id AS assocID, COUNT(*) AS cnt FROM uem_cp.emc_uem_uascifsshareleaf AS US, uem_cp.emc_uem_uascifsshareidentityassocleaf AS ASSC WHERE US.id = ASSC.sameelementid AND ASSC.sameelementtype = 'root/emc:EMC_UEM_UASCIFSShareLeaf' GROUP BY US.id, ASSC.id HAVING COUNT(*) = 1 ORDER BY US.id) AS foo);"
echo
echo Non-associated CIFS Shares by InstanceName keys
psql -d uemcpdb -U uem_cp_usr -c "SELECT InstanceID AS CIFSShare_InstanceID FROM uem_cp.emc_uem_uascifsshareleaf EXCEPT (SELECT CIFSShare_InstanceID FROM (SELECT US.InstanceID AS CIFSShare_InstanceID, ASSC.id AS assocID, COUNT(*) AS cnt FROM uem_cp.emc_uem_uascifsshareleaf AS US, uem_cp.emc_uem_uascifsshareidentityassocleaf AS ASSC WHERE ASSC.sameelementinstancename = TEXTCAT('root/emc:EMC_UEM_UASCIFSShareLeaf%InstanceID=', US.InstanceID) GROUP BY US.InstanceID, ASSC.id HAVING COUNT(*) = 1 ORDER BY US.InstanceID) AS foo);"
echo
echo More than 1 association
psql -d uemcpdb -U uem_cp_usr -c "SELECT CIFSShare_InstanceID, cnt AS Number_of_Associations FROM (SELECT US.InstanceID AS CIFSShare_InstanceID, ASSC.id AS assocID, COUNT(*) AS cnt FROM uem_cp.emc_uem_uascifsshareleaf AS US, uem_cp.emc_uem_uascifsshareidentityassocleaf AS ASSC WHERE ASSC.sameelementinstancename = TEXTCAT('root/emc:EMC_UEM_UASCIFSShareLeaf%InstanceID=', US.InstanceID) GROUP BY US.InstanceID, ASSC.id HAVING COUNT(*) > 1 ORDER BY US.InstanceID) AS foo;"
echo

echo -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
echo "26. File system snaps associated each with the only NAS checkpoint (1"
echo
echo "UASFileSystemSnap 1:1 --- UASFileSystemSnapIdentityAssocLeaf ----> 1:1 NASCheckpoint"
echo
echo Non-associated File System Snaps by internal integer keys
psql -d uemcpdb -U uem_cp_usr -c "SELECT id AS fssid FROM uem_cp.emc_uem_uasfilesystemsnapleaf EXCEPT (SELECT fssid FROM (SELECT FSN.id AS fssid, ASSC.id AS assocID, CK.id AS ckid, COUNT(*) AS cnt FROM uem_cp.emc_uem_uasfilesystemsnapleaf AS FSN, uem_cp.emc_uem_uasfilesystemsnapidentityassocleaf AS ASSC, uem_cp.cimnas_checkpoint AS CK WHERE FSN.id = ASSC.sameelementid AND CK.id = ASSC.systemelementid AND ASSC.sameelementtype = 'root/emc:EMC_UEM_UASFileSystemSnapLeaf' GROUP BY FSN.id, ASSC.id, CK.id HAVING COUNT(*) = 1 ORDER BY FSN.id, CK.id) AS foo);"
echo
echo Non-associated File System Snaps by InstanceName keys
psql -d uemcpdb -U uem_cp_usr -c "SELECT InstanceID AS UASFileSystemSnap_InstanceID FROM uem_cp.emc_uem_uasfilesystemsnapleaf EXCEPT (SELECT UASFileSystemSnap_InstanceID FROM (SELECT FSN.InstanceID AS UASFileSystemSnap_InstanceID, ASSC.id AS assocID, CK.nas_id AS Checkpoint_nas_id, COUNT(*) AS cnt FROM uem_cp.emc_uem_uasfilesystemsnapleaf AS FSN, uem_cp.emc_uem_uasfilesystemsnapidentityassocleaf AS ASSC, uem_cp.cimnas_checkpoint AS CK WHERE ASSC.sameelementinstancename = TEXTCAT('root/emc:EMC_UEM_UASFileSystemSnapLeaf%InstanceID=', FSN.InstanceID) AND ASSC.systemelementinstancename = TEXTCAT('emc/cimnas:CIMNAS_Checkpoint%id=', CAST(CK.nas_id AS TEXT)) GROUP BY FSN.InstanceID, ASSC.id, CK.nas_id HAVING COUNT(*) = 1 ORDER BY FSN.InstanceID) AS foo);"
echo
echo More than 1 association
psql -d uemcpdb -U uem_cp_usr -c "SELECT UASFileSystemSnap_InstanceID, cnt AS Number_of_Associations FROM (SELECT FSN.InstanceID AS UASFileSystemSnap_InstanceID, ASSC.id AS assocID, CK.nas_id AS Checkpoint_nas_id, COUNT(*) AS cnt FROM uem_cp.emc_uem_uasfilesystemsnapleaf AS FSN, uem_cp.emc_uem_uasfilesystemsnapidentityassocleaf AS ASSC, uem_cp.cimnas_checkpoint AS CK WHERE ASSC.sameelementinstancename = TEXTCAT('root/emc:EMC_UEM_UASFileSystemSnapLeaf%InstanceID=', FSN.InstanceID) AND ASSC.systemelementinstancename = TEXTCAT('emc/cimnas:CIMNAS_Checkpoint%id=', CAST(CK.nas_id AS TEXT)) GROUP BY FSN.InstanceID, ASSC.id, CK.nas_id HAVING COUNT(*) > 1 ORDER BY FSN.InstanceID) AS foo;"
echo

echo -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
echo "27. File system snaps have the only association with NAS checkpoint (1"
echo
echo "UASFileSystemSnap 1:1 --- UASFileSystemSnapIdentityAssocLeaf ---->"
echo
echo Non-associated File System Snaps by internal integer keys
psql -d uemcpdb -U uem_cp_usr -c "SELECT id AS fssid FROM uem_cp.emc_uem_uasfilesystemsnapleaf EXCEPT (SELECT fssid FROM (SELECT FSN.id AS fssid, ASSC.id AS assocID, COUNT(*) AS cnt FROM uem_cp.emc_uem_uasfilesystemsnapleaf AS FSN, uem_cp.emc_uem_uasfilesystemsnapidentityassocleaf AS ASSC WHERE FSN.id = ASSC.sameelementid AND ASSC.sameelementtype = 'root/emc:EMC_UEM_UASFileSystemSnapLeaf' GROUP BY FSN.id, ASSC.id HAVING COUNT(*) = 1 ORDER BY FSN.id) AS foo);"
echo
echo Non-associated File System Snaps by InstanceName keys
psql -d uemcpdb -U uem_cp_usr -c "SELECT InstanceID AS UASFileSystemSnap_InstanceID FROM uem_cp.emc_uem_uasfilesystemsnapleaf EXCEPT (SELECT UASFileSystemSnap_InstanceID FROM (SELECT FSN.InstanceID AS UASFileSystemSnap_InstanceID, ASSC.id AS assocID, COUNT(*) AS cnt FROM uem_cp.emc_uem_uasfilesystemsnapleaf AS FSN, uem_cp.emc_uem_uasfilesystemsnapidentityassocleaf AS ASSC WHERE ASSC.sameelementinstancename = TEXTCAT('root/emc:EMC_UEM_UASFileSystemSnapLeaf%InstanceID=', FSN.InstanceID) GROUP BY FSN.InstanceID, ASSC.id HAVING COUNT(*) = 1 ORDER BY FSN.InstanceID) AS foo);"
echo
echo More than 1 association
psql -d uemcpdb -U uem_cp_usr -c "SELECT UASFileSystemSnap_InstanceID, cnt AS Number_of_Associations FROM (SELECT FSN.InstanceID AS UASFileSystemSnap_InstanceID, ASSC.id AS assocID, COUNT(*) AS cnt FROM uem_cp.emc_uem_uasfilesystemsnapleaf AS FSN, uem_cp.emc_uem_uasfilesystemsnapidentityassocleaf AS ASSC WHERE ASSC.sameelementinstancename = TEXTCAT('root/emc:EMC_UEM_UASFileSystemSnapLeaf%InstanceID=', FSN.InstanceID) GROUP BY FSN.InstanceID, ASSC.id HAVING COUNT(*) > 1 ORDER BY FSN.InstanceID) AS foo;"
echo

echo -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
echo "28. Storage volume snaps associated each with the only NAS iSCSI snap (1"
echo
echo "UASStorageVolumeSnap 1:1 --- UASStorageVolumeSnapIdentityAssocLeaf ----> 1:1 NASiSCSISnap"
echo
echo Non-associated Storage Volume Snaps by internal integer keys
psql -d uemcpdb -U uem_cp_usr -c "SELECT id AS svsid FROM uem_cp.emc_uem_uasstoragevolumesnapleaf EXCEPT (SELECT svsid FROM (SELECT SVSN.id AS svsid, ASSC.id AS assocID, ISC.id AS ckid, COUNT(*) AS cnt FROM uem_cp.emc_uem_uasstoragevolumesnapleaf AS SVSN, uem_cp.emc_uem_uasstoragevolumesnapidentityassocleaf AS ASSC, uem_cp.cimnas_iscsisnap AS ISC WHERE SVSN.id = ASSC.sameelementid AND ISC.id = ASSC.systemelementid AND ASSC.sameelementtype = 'root/emc:EMC_UEM_UASStorageVolumeSnapLeaf' GROUP BY SVSN.id, ASSC.id, ISC.id HAVING COUNT(*) = 1 ORDER BY SVSN.id, ISC.id) AS foo);"
echo
echo Non-associated Storage Volume Snaps by InstanceName keys
psql -d uemcpdb -U uem_cp_usr -c "SELECT InstanceID AS StorageVolumeSnap_InstanceID FROM uem_cp.emc_uem_uasstoragevolumesnapleaf EXCEPT (SELECT StorageVolumeSnap_InstanceID FROM (SELECT SVSN.InstanceID AS StorageVolumeSnap_InstanceID, ASSC.id AS assocID, ISS.nas_id AS iSACSISnap_nas_id, ISS.mover AS iSACSISnap_mover, COUNT(*) AS cnt FROM uem_cp.emc_uem_uasstoragevolumesnapleaf AS SVSN, uem_cp.emc_uem_uasstoragevolumesnapidentityassocleaf AS ASSC, uem_cp.cimnas_iscsisnap AS ISS WHERE ASSC.sameelementinstancename = TEXTCAT('root/emc:EMC_UEM_UASStorageVolumeSnapLeaf%InstanceID=', SVSN.InstanceID) AND ASSC.systemelementinstancename = TEXTCAT(TEXTCAT(TEXTCAT('emc/cimnas:CIMNAS_iSCSISnap%id=', ISS.nas_id), '%mover='), ISS.mover) GROUP BY SVSN.InstanceID, ASSC.id, ISS.nas_id, ISS.mover HAVING COUNT(*) = 1 ORDER BY SVSN.InstanceID) AS foo);"
echo
echo More than 1 association
psql -d uemcpdb -U uem_cp_usr -c "SELECT StorageVolumeSnap_InstanceID, cnt AS Number_of_Associations FROM (SELECT SVSN.InstanceID AS StorageVolumeSnap_InstanceID, ASSC.id AS assocID, ISS.nas_id AS iSACSISnap_nas_id, ISS.mover AS iSACSISnap_mover, COUNT(*) AS cnt FROM uem_cp.emc_uem_uasstoragevolumesnapleaf AS SVSN, uem_cp.emc_uem_uasstoragevolumesnapidentityassocleaf AS ASSC, uem_cp.cimnas_iscsisnap AS ISS WHERE ASSC.sameelementinstancename = TEXTCAT('root/emc:EMC_UEM_UASStorageVolumeSnapLeaf%InstanceID=', SVSN.InstanceID) AND ASSC.systemelementinstancename = TEXTCAT(TEXTCAT(TEXTCAT('emc/cimnas:CIMNAS_iSCSISnap%id=', ISS.nas_id), '%mover='), ISS.mover) GROUP BY SVSN.InstanceID, ASSC.id, ISS.nas_id, ISS.mover HAVING COUNT(*) > 1 ORDER BY SVSN.InstanceID) AS foo;"
echo

echo -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
echo "29. Storage volumes snaps have the only association with NAS iSCSI snap (1"
echo
echo "UASStorageVolumeSnap 1:1 --- UASStorageVolumeSnapIdentityAssocLeaf ---->"
echo
echo Non-associated Storage Volume Snaps by internal integer keys
psql -d uemcpdb -U uem_cp_usr -c "SELECT id AS svsid FROM uem_cp.emc_uem_uasstoragevolumesnapleaf EXCEPT (SELECT svsid FROM (SELECT SVSN.id AS svsid, ASSC.id AS assocID, COUNT(*) AS cnt FROM uem_cp.emc_uem_uasstoragevolumesnapleaf AS SVSN, uem_cp.emc_uem_uasstoragevolumesnapidentityassocleaf AS ASSC WHERE SVSN.id = ASSC.sameelementid AND ASSC.sameelementtype = 'root/emc:EMC_UEM_UASStorageVolumeSnapLeaf' GROUP BY SVSN.id, ASSC.id HAVING COUNT(*) = 1 ORDER BY SVSN.id) AS foo);"
echo
echo Non-associated Storage Volume Snaps by InstanceName keys
psql -d uemcpdb -U uem_cp_usr -c "SELECT InstanceID AS StorageVolumeSnap_InstanceID FROM uem_cp.emc_uem_uasstoragevolumesnapleaf EXCEPT (SELECT StorageVolumeSnap_InstanceID FROM (SELECT SVSN.InstanceID AS StorageVolumeSnap_InstanceID, ASSC.id AS assocID, COUNT(*) AS cnt FROM uem_cp.emc_uem_uasstoragevolumesnapleaf AS SVSN, uem_cp.emc_uem_uasstoragevolumesnapidentityassocleaf AS ASSC WHERE ASSC.sameelementinstancename = TEXTCAT('root/emc:EMC_UEM_UASStorageVolumeSnapLeaf%InstanceID=', SVSN.InstanceID) GROUP BY SVSN.InstanceID, ASSC.id HAVING COUNT(*) = 1 ORDER BY SVSN.InstanceID) AS foo);"
echo
echo More than 1 association
psql -d uemcpdb -U uem_cp_usr -c "SELECT StorageVolumeSnap_InstanceID, cnt AS Number_of_Associations FROM (SELECT SVSN.InstanceID AS StorageVolumeSnap_InstanceID, ASSC.id AS assocID, COUNT(*) AS cnt FROM uem_cp.emc_uem_uasstoragevolumesnapleaf AS SVSN, uem_cp.emc_uem_uasstoragevolumesnapidentityassocleaf AS ASSC WHERE ASSC.sameelementinstancename = TEXTCAT('root/emc:EMC_UEM_UASStorageVolumeSnapLeaf%InstanceID=', SVSN.InstanceID) GROUP BY SVSN.InstanceID, ASSC.id HAVING COUNT(*) > 1 ORDER BY SVSN.InstanceID) AS foo;"
echo

echo -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
echo "30. Applications assoicated each with the only EMC_StorageServer (1"
echo
echo "UASApplication 1:1 ---- UASApplicationStorageServerAssocLeaf -----> 1:1"
echo
echo "Non-associated Application by internal integer keys (Warning)"
psql -d uemcpdb -U uem_cp_usr -c "SELECT id AS appid FROM uem_cp.emc_uem_uasapplicationleaf EXCEPT (SELECT appid FROM (SELECT APP.id AS appid, ASSC.id AS assocID, COUNT(*) AS cnt FROM uem_cp.emc_uem_uasapplicationleaf AS APP, uem_cp.emc_uem_uasapplicationstorageserverassocleaf AS ASSC WHERE APP.id = ASSC.antecedentid AND ASSC.antecedenttype = 'root/emc:EMC_UEM_UASApplicationLeaf' GROUP BY APP.id, ASSC.id HAVING COUNT(*) = 1 ORDER BY APP.id) AS foo);"
echo
echo "Non-associated Application by InstanceName keys (Warning)"
psql -d uemcpdb -U uem_cp_usr -c "SELECT InstanceID AS Application_InstanceID FROM uem_cp.emc_uem_uasapplicationleaf EXCEPT (SELECT Application_InstanceID FROM (SELECT APP.InstanceID AS Application_InstanceID, ASSC.dependentinstancename AS StorageServer, COUNT(*) AS CNT FROM uem_cp.emc_uem_uasapplicationleaf AS APP, uem_cp.emc_uem_uasapplicationstorageserverassocleaf AS ASSC WHERE ASSC.antecedentinstancename = TEXTCAT('root/emc:EMC_UEM_UASApplicationLeaf%InstanceID=', APP.InstanceID) GROUP BY APP.InstanceID, ASSC.dependentinstancename HAVING COUNT(*) = 1 ORDER BY APP.InstanceID) AS foo);"
echo
echo More than 1 association
psql -d uemcpdb -U uem_cp_usr -c "SELECT Application_InstanceID, cnt AS Number_of_Associations FROM (SELECT APP.InstanceID AS Application_InstanceID, ASSC.dependentinstancename AS StorageServer, COUNT(*) AS CNT FROM uem_cp.emc_uem_uasapplicationleaf AS APP, uem_cp.emc_uem_uasapplicationstorageserverassocleaf AS ASSC WHERE ASSC.antecedentinstancename = TEXTCAT('root/emc:EMC_UEM_UASApplicationLeaf%InstanceID=', APP.InstanceID) GROUP BY APP.InstanceID, ASSC.dependentinstancename HAVING COUNT(*) > 1 ORDER BY APP.InstanceID) AS foo;"
echo

echo -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
echo "31. NAS file systems associated either with UAS file systems or with UAS Storage volumes (1"
echo
echo "NASFilesystem 1:1 ----- UASFileSystemIdentityAssocLeaf, UASStorageFolumeFSIdentityAssocLeaf -----> 1:1 UASFileSystem || UASStorageVolume"
echo
echo Non-associated NAS File Systems by internal integer keys
psql -d uemcpdb -U uem_cp_usr -c "SELECT id AS nfsid FROM uem_cp.cimnas_filesystem WHERE name NOT LIKE 'root_%' AND name NOT LIKE 'vpfs%' EXCEPT ((SELECT nfsid FROM (SELECT NFS.id AS nfsid, ASSC.id AS assocID, FS.id AS fsid, COUNT(*) AS cnt FROM uem_cp.cimnas_filesystem AS NFS, uem_cp.emc_uem_uasfilesystemidentityassocleaf AS ASSC, uem_cp.emc_uem_uasfilesystemleaf AS FS WHERE FS.id = ASSC.sameelementid AND NFS.id = ASSC.systemelementid AND ASSC.sameelementtype = 'root/emc:EMC_UEM_UASFileSystemLeaf' GROUP BY NFS.id, ASSC.id, FS.id HAVING COUNT(*) = 1 ORDER BY NFS.id, FS.id) AS foo) UNION (SELECT nfsid FROM (SELECT NFS.id AS nfsid, ASSC.id AS assocID, SV.id AS svid, COUNT(*) AS cnt FROM uem_cp.cimnas_filesystem AS NFS, uem_cp.emc_uem_uasstoragevolumefsidentityassocleaf AS ASSC, uem_cp.emc_uem_uasstoragevolumeleaf AS SV WHERE SV.id = ASSC.sameelementid AND NFS.id = ASSC.systemelementid AND ASSC.sameelementtype = 'root/emc:EMC_UEM_UASStorageVolumeLeaf' GROUP BY NFS.id, ASSC.id, SV.id HAVING COUNT(*) = 1 ORDER BY NFS.id, SV.id) AS bar));"
echo
echo Non-associated NAS File Systems by InstanceName keys
psql -d uemcpdb -U uem_cp_usr -c "SELECT nas_id AS NASFileSystem_nas_id FROM uem_cp.cimnas_filesystem WHERE name NOT LIKE 'root_%' AND name NOT LIKE 'vpfs%' EXCEPT ((SELECT NASFileSystem_nas_id FROM (SELECT NFS.nas_id AS NASFileSystem_nas_id, ASSC.id AS assocID, FS.InstanceID AS UASFileSystem_instanceID, COUNT(*) AS cnt FROM uem_cp.cimnas_filesystem AS NFS, uem_cp.emc_uem_uasfilesystemidentityassocleaf AS ASSC, uem_cp.emc_uem_uasfilesystemleaf AS FS WHERE ASSC.sameelementinstancename = TEXTCAT('root/emc:EMC_UEM_UASFileSystemLeaf%InstanceID=', FS.InstanceID) AND ASSC.systemelementinstancename = TEXTCAT('emc/cimnas:CIMNAS_Filesystem%id=', CAST(NFS.nas_id AS TEXT)) GROUP BY NFS.nas_id, ASSC.id, FS.InstanceID HAVING COUNT(*) = 1 ORDER BY NFS.nas_id) AS foo) UNION (SELECT NASFileSystem_nas_id FROM (SELECT NFS.nas_id AS NASFileSystem_nas_id, ASSC.id AS assocID, SV.InstanceID AS UASStorageVolume_InstanceID, COUNT(*) AS cnt FROM uem_cp.cimnas_filesystem AS NFS, uem_cp.emc_uem_uasstoragevolumefsidentityassocleaf AS ASSC, uem_cp.emc_uem_uasstoragevolumeleaf AS SV WHERE ASSC.sameelementinstancename = TEXTCAT('root/emc:EMC_UEM_UASStorageVolumeLeaf%InstanceID=', SV.InstanceID) AND ASSC.systemelementinstancename = TEXTCAT('emc/cimnas:CIMNAS_Filesystem%id=', CAST(NFS.nas_id AS TEXT)) GROUP BY NFS.nas_id, ASSC.id, SV.InstanceID HAVING COUNT(*) = 1 ORDER BY NFS.nas_id) AS bar));"
echo
echo Restores integer keys using InstanceName keys
echo Can be used if there are Non-associated NAS Shares by internal integer keys and no Non-associated NAS Shares by InstanceName keys
echo "UPDATE uem_cp.emc_uem_uasfilesystemidentityassocleaf AS ASSC SET systemelementid = NFS.id, sameelementid = FS.id FROM uem_cp.cimnas_filesystem AS NFS, uem_cp.emc_uem_uasfilesystemleaf AS FS WHERE ASSC.sameelementinstancename = TEXTCAT('root/emc:EMC_UEM_UASFileSystemLeaf%InstanceID=', FS.InstanceID) AND ASSC.systemelementinstancename = TEXTCAT('emc/cimnas:CIMNAS_Filesystem%id=', CAST(NFS.nas_id AS TEXT));"
echo
echo Restores integer keys using InstanceName keys
echo Can be used if there are Non-associated NAS Shares by internal integer keys and no Non-associated NAS Shares by InstanceName keys
echo "UPDATE uem_cp.emc_uem_uasstoragevolumefsidentityassocleaf AS ASSC SET systemelementid = NFS.id, sameelementid = SV.id FROM uem_cp.cimnas_filesystem AS NFS, uem_cp.emc_uem_uasstoragevolumeleaf AS SV WHERE ASSC.sameelementinstancename = TEXTCAT('root/emc:EMC_UEM_UASStorageVolumeLeaf%InstanceID=', SV.InstanceID) AND ASSC.systemelementinstancename = TEXTCAT('emc/cimnas:CIMNAS_Filesystem%id=', CAST(NFS.nas_id AS TEXT));"
echo

echo -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
echo "32. NAS iSCSI Luns associated with UAS Storage volumes (1"
echo
echo "NASiSCSILun 1:1 ---- UASStorageVolumeIdentityAssocLeaf ----- > 1:1 UASStorageVolume"
echo
echo Non-associated NAS iSCSI LUNs by internal integer keys
psql -d uemcpdb -U uem_cp_usr -c "SELECT id AS cimnas_iscsilun_ID FROM uem_cp.cimnas_iscsilun EXCEPT (SELECT foo.lunid AS cimnas_iscsilun_ID FROM (SELECT LUN.id AS lunid, ASSC.id AS assocID, SV.id AS svid, COUNT(*) AS cnt FROM uem_cp.emc_uem_uasstoragevolumeleaf AS SV, uem_cp.emc_uem_uasstoragevolumeidentityassocleaf AS ASSC, uem_cp.cimnas_iscsilun AS LUN WHERE SV.id = ASSC.sameelementid AND LUN.id = ASSC.systemelementid AND ASSC.sameelementtype = 'root/emc:EMC_UEM_UASStorageVolumeLeaf' GROUP BY SV.id, ASSC.id, LUN.id HAVING COUNT(*) = 1 ORDER BY LUN.id) AS foo);"
echo
echo Non-associated NAS iSCSI LUNs by InstanceName keys
psql -d uemcpdb -U uem_cp_usr -c "SELECT mover AS LUN_mover, number AS LUN_number, target AS LUN_target FROM uem_cp.cimnas_iscsilun EXCEPT (SELECT foo.LUN_mover, foo.LUN_number, foo.LUN_target FROM (SELECT LUN.mover AS LUN_mover, LUN.number AS LUN_number, LUN.target AS LUN_target, ASSC.id AS assocID, SV.InstanceID AS StorageVolume_InstanceID, COUNT(*) AS cnt FROM uem_cp.emc_uem_uasstoragevolumeleaf AS SV, uem_cp.emc_uem_uasstoragevolumeidentityassocleaf AS ASSC, uem_cp.cimnas_iscsilun AS LUN WHERE ASSC.sameelementinstancename = TEXTCAT('root/emc:EMC_UEM_UASStorageVolumeLeaf%InstanceID=', SV.InstanceID) AND ASSC.systemelementinstancename = TEXTCAT(TEXTCAT(TEXTCAT(TEXTCAT(TEXTCAT('emc/cimnas:CIMNAS_iSCSILun%mover=', LUN.mover), '%number='), CAST(LUN.number AS TEXT)), '%target='), LUN.target) GROUP BY LUN.mover, LUN.number, LUN.target, ASSC.id, SV.InstanceID HAVING COUNT(*) = 1 ORDER BY LUN.mover, LUN.number, LUN.target) AS foo);"
echo
echo More than 1 association
psql -d uemcpdb -U uem_cp_usr -c "SELECT foo.LUN_mover, foo.LUN_number, foo.LUN_target, foo.cnt AS Number_of_Associations FROM (SELECT LUN.mover AS LUN_mover, LUN.number AS LUN_number, LUN.target AS LUN_target, ASSC.id AS assocID, SV.InstanceID AS StorageVolume_InstanceID, COUNT(*) AS cnt FROM uem_cp.emc_uem_uasstoragevolumeleaf AS SV, uem_cp.emc_uem_uasstoragevolumeidentityassocleaf AS ASSC, uem_cp.cimnas_iscsilun AS LUN WHERE ASSC.sameelementinstancename = TEXTCAT('root/emc:EMC_UEM_UASStorageVolumeLeaf%InstanceID=', SV.InstanceID) AND ASSC.systemelementinstancename = TEXTCAT(TEXTCAT(TEXTCAT(TEXTCAT(TEXTCAT('emc/cimnas:CIMNAS_iSCSILun%mover=', LUN.mover), '%number='), CAST(LUN.number AS TEXT)), '%target='), LUN.target) GROUP BY LUN.mover, LUN.number, LUN.target, ASSC.id, SV.InstanceID HAVING COUNT(*) > 1 ORDER BY LUN.mover, LUN.number, LUN.target) AS foo;"
echo
echo Restores integer keys using InstanceName keys
echo Can be used if there are Non-associated NAS Shares by internal integer keys and no Non-associated NAS Shares by InstanceName keys
echo "UPDATE uem_cp.emc_uem_uasstoragevolumeidentityassocleaf  AS ASSC SET systemelementid = LUN.id, sameelementid = SV.id FROM uem_cp.emc_uem_uasstoragevolumeleaf AS SV, uem_cp.cimnas_iscsilun AS LUN WHERE ASSC.sameelementinstancename = TEXTCAT('root/emc:EMC_UEM_UASStorageVolumeLeaf%InstanceID=', SV.InstanceID) AND ASSC.systemelementinstancename = TEXTCAT(TEXTCAT(TEXTCAT(TEXTCAT(TEXTCAT('emc/cimnas:CIMNAS_iSCSILun%mover=', LUN.mover), '%number='), CAST(LUN.number AS TEXT)), '%target='), LUN.target);"
echo


echo -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
echo "33. NAS checkpoints associated with UAS file system snaps (1"
echo
echo "NASCheckpoint 1:1 ---- UASFileSystemSnapIdentityAssocLeaf -----> 1:1 UASFileSystemSnap"
echo
echo "Non-associated NAS file system checkpoint by internal integer keys. No error if these are writeable checkpoints created as promoted checkpoints."
psql -d uemcpdb -U uem_cp_usr -c "SELECT id AS cimnas_checkpoint_ID FROM uem_cp.cimnas_checkpoint EXCEPT (SELECT foo.ckid AS cimnas_checkpoint_ID FROM (SELECT CK.id AS ckid, ASSC.id AS assocID, FSN.id AS fsnid, COUNT(*) AS cnt FROM uem_cp.emc_uem_uasfilesystemsnapleaf AS FSN, uem_cp.emc_uem_uasfilesystemsnapidentityassocleaf AS ASSC, uem_cp.cimnas_checkpoint AS CK WHERE FSN.id = ASSC.sameelementid AND CK.id = ASSC.systemelementid AND ASSC.sameelementtype = 'root/emc:EMC_UEM_UASFileSystemSnapLeaf' GROUP BY CK.id, ASSC.id, FSN.id HAVING COUNT(*) = 1 ORDER BY CK.id) AS foo);"
echo
echo "Non-associated NAS file system checkpoint by InstanceName keys. No error if these are writeable checkpoints created as promoted checkpoints."
psql -d uemcpdb -U uem_cp_usr -c "SELECT nas_id AS cimnas_checkpoint_nas_id FROM uem_cp.cimnas_checkpoint EXCEPT (SELECT cimnas_checkpoint_nas_id FROM (SELECT CK.nas_id AS cimnas_checkpoint_nas_id, ASSC.id AS assocID, FSN.InstanceID AS FileSystemSnap_InstanceID, COUNT(*) AS cnt FROM uem_cp.emc_uem_uasfilesystemsnapleaf AS FSN, uem_cp.emc_uem_uasfilesystemsnapidentityassocleaf AS ASSC, uem_cp.cimnas_checkpoint AS CK WHERE ASSC.sameelementinstancename = TEXTCAT('root/emc:EMC_UEM_UASFileSystemSnapLeaf%InstanceID=', FSN.InstanceID) AND ASSC.systemelementinstancename = TEXTCAT('emc/cimnas:CIMNAS_Checkpoint%id=', CAST(CK.nas_id AS TEXT)) GROUP BY CK.nas_id, ASSC.id, FSN.InstanceID HAVING COUNT(*) = 1 ORDER BY CK.nas_id) AS foo);"
echo
echo More than 1 association
psql -d uemcpdb -U uem_cp_usr -c "SELECT cimnas_checkpoint_nas_id, cnt AS Number_of_Associations FROM (SELECT CK.nas_id AS cimnas_checkpoint_nas_id, ASSC.id AS assocID, FSN.InstanceID AS FileSystemSnap_InstanceID, COUNT(*) AS cnt FROM uem_cp.emc_uem_uasfilesystemsnapleaf AS FSN, uem_cp.emc_uem_uasfilesystemsnapidentityassocleaf AS ASSC, uem_cp.cimnas_checkpoint AS CK WHERE ASSC.sameelementinstancename = TEXTCAT('root/emc:EMC_UEM_UASFileSystemSnapLeaf%InstanceID=', FSN.InstanceID) AND ASSC.systemelementinstancename = TEXTCAT('emc/cimnas:CIMNAS_Checkpoint%id=', CAST(CK.nas_id AS TEXT)) GROUP BY CK.nas_id, ASSC.id, FSN.InstanceID HAVING COUNT(*) > 1 ORDER BY CK.nas_id) AS foo;"
echo
echo Restores integer keys using InstanceName keys
echo Can be used if there are Non-associated NAS Shares by internal integer keys and no Non-associated NAS Shares by InstanceName keys
echo "UPDATE uem_cp.emc_uem_uasfilesystemsnapidentityassocleaf AS ASSC SET systemelementid = CK.id, sameelementid = FSN.id FROM uem_cp.emc_uem_uasfilesystemsnapleaf AS FSN, uem_cp.cimnas_checkpoint AS CK WHERE ASSC.sameelementinstancename = TEXTCAT('root/emc:EMC_UEM_UASFileSystemSnapLeaf%InstanceID=', FSN.InstanceID) AND ASSC.systemelementinstancename = TEXTCAT('emc/cimnas:CIMNAS_Checkpoint%id=', CAST(CK.nas_id AS TEXT));"
echo
echo -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
echo "34. NAS iSCSI snaps associated with UAS storage volume snaps (1"
echo 
echo "NASiSCSISnap 1:1 ---- UASStorageVolumeSnapIdentityAssocLeaf -----> 1:1 UASStorageVolumeSnap"
echo
echo Non-associated iSCSI Snap by internal integer keys
psql -d uemcpdb -U uem_cp_usr -c "SELECT id AS cimnas_iscsisnap_ID FROM uem_cp.cimnas_iscsisnap EXCEPT (SELECT foo.issid AS cimnas_iscsisnap_ID FROM (SELECT ISS.id AS issid, ASSC.id AS assocID, SVSN.id AS svsnid, COUNT(*) AS cnt FROM uem_cp.emc_uem_uasstoragevolumesnapleaf AS SVSN, uem_cp.emc_uem_uasstoragevolumesnapidentityassocleaf AS ASSC, uem_cp.cimnas_iscsisnap AS ISS WHERE SVSN.id = ASSC.sameelementid AND ISS.id = ASSC.systemelementid AND ASSC.sameelementtype = 'root/emc:EMC_UEM_UASStorageVolumeSnapLeaf' GROUP BY ISS.id, ASSC.id, SVSN.id HAVING COUNT(*) = 1 ORDER BY ISS.id) AS foo);"
echo
echo Non-associated iSCSI Snaps by InstanceName keys
psql -d uemcpdb -U uem_cp_usr -c "SELECT nas_id AS iSCSISnap_nas_id, mover AS iSCSISnap_mover FROM uem_cp.cimnas_iscsisnap EXCEPT (SELECT iSCSISnap_nas_id, iSCSISnap_mover FROM (SELECT ISS.nas_id AS iSCSISnap_nas_id, ISS.mover AS iSCSISnap_mover, ASSC.id AS assocID, SVSN.InstanceID AS StorageVolumeSnap_InstanceID, COUNT(*) AS cnt FROM uem_cp.emc_uem_uasstoragevolumesnapleaf AS SVSN, uem_cp.emc_uem_uasstoragevolumesnapidentityassocleaf AS ASSC, uem_cp.cimnas_iscsisnap AS ISS WHERE ASSC.sameelementinstancename = TEXTCAT('root/emc:EMC_UEM_UASStorageVolumeSnapLeaf%InstanceID=', SVSN.InstanceID) AND ASSC.systemelementinstancename = TEXTCAT(TEXTCAT(TEXTCAT('emc/cimnas:CIMNAS_iSCSISnap%id=', ISS.nas_id), '%mover='), ISS.mover) GROUP BY ISS.nas_id, ISS.mover, ASSC.id, SVSN.InstanceID HAVING COUNT(*) = 1 ORDER BY ISS.nas_id, ISS.mover) AS foo);"
echo
echo More than 1 association
psql -d uemcpdb -U uem_cp_usr -c "SELECT iSCSISnap_nas_id, iSCSISnap_mover, cnt AS Number_of_Associations FROM (SELECT ISS.nas_id AS iSCSISnap_nas_id, ISS.mover AS iSCSISnap_mover, ASSC.id AS assocID, SVSN.InstanceID AS StorageVolumeSnap_InstanceID, COUNT(*) AS cnt FROM uem_cp.emc_uem_uasstoragevolumesnapleaf AS SVSN, uem_cp.emc_uem_uasstoragevolumesnapidentityassocleaf AS ASSC, uem_cp.cimnas_iscsisnap AS ISS WHERE ASSC.sameelementinstancename = TEXTCAT('root/emc:EMC_UEM_UASStorageVolumeSnapLeaf%InstanceID=', SVSN.InstanceID) AND ASSC.systemelementinstancename = TEXTCAT(TEXTCAT(TEXTCAT('emc/cimnas:CIMNAS_iSCSISnap%id=', ISS.nas_id), '%mover='), ISS.mover) GROUP BY ISS.nas_id, ISS.mover, ASSC.id, SVSN.InstanceID HAVING COUNT(*) > 1 ORDER BY ISS.nas_id, ISS.mover) AS foo;"
echo
echo Restores integer keys using InstanceName keys
echo Can be used if there are Non-associated NAS Shares by internal integer keys and no Non-associated NAS Shares by InstanceName keys
echo "UPDATE uem_cp.emc_uem_uasstoragevolumesnapidentityassocleaf AS ASSC SET systemelementid = ISS.id, sameelementid = SVSN.id FROM uem_cp.emc_uem_uasstoragevolumesnapleaf AS SVSN, uem_cp.cimnas_iscsisnap AS ISS WHERE ASSC.sameelementinstancename = TEXTCAT('root/emc:EMC_UEM_UASStorageVolumeSnapLeaf%InstanceID=', SVSN.InstanceID) AND ASSC.systemelementinstancename = TEXTCAT(TEXTCAT(TEXTCAT('emc/cimnas:CIMNAS_iSCSISnap%id=', ISS.nas_id), '%mover='), ISS.mover);"
echo

echo -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
echo "35. NAS exports associated with UAS NFS share (1"
echo
echo "NASExport 1:1 ---- UASNFSShareIdentityAssocLeaf -----> 1:1 UASNFSShare"
echo
echo Non-associated NAS Exports by internal integer keys
psql -d uemcpdb -U uem_cp_usr -c "SELECT id AS cimnas_export_id FROM uem_cp.cimnas_export EXCEPT (SELECT foo.expid AS cimnas_export_id FROM (SELECT US.id AS shareid, ASSC.id AS assocID, NE.id AS expid, COUNT(*) AS cnt FROM uem_cp.emc_uem_uasnfsshareleaf AS US, uem_cp.emc_uem_uasnfsshareidentityassocleaf AS ASSC, uem_cp.cimnas_export AS NE WHERE US.id = ASSC.sameelementid AND NE.id = ASSC.systemelementid AND ASSC.sameelementtype = 'root/emc:EMC_UEM_UASNFSShareLeaf' GROUP BY US.id, ASSC.id, NE.id HAVING COUNT(*) = 1 ORDER BY US.id, NE.id) AS foo);"
echo
echo Non-associated NAS Exports by InstanceName keys
psql -d uemcpdb -U uem_cp_usr -c "SELECT mover AS NASExport_mover, path AS NASExport_path FROM uem_cp.cimnas_export EXCEPT (SELECT NASExport_mover, NASExport_path FROM (SELECT NE.mover AS NASExport_mover, NE.path AS NASExport_path, ASSC.id AS assocID, US.InstanceID AS NFSShare_InstanceID, COUNT(*) AS cnt FROM uem_cp.emc_uem_uasnfsshareleaf AS US, uem_cp.emc_uem_uasnfsshareidentityassocleaf AS ASSC, uem_cp.cimnas_export AS NE WHERE ASSC.sameelementinstancename = TEXTCAT('root/emc:EMC_UEM_UASNFSShareLeaf%InstanceID=', US.InstanceID) AND ASSC.systemelementinstancename = TEXTCAT(TEXTCAT(TEXTCAT('emc/cimnas:CIMNAS_Export%mover=', NE.mover), '%path='), NE.path) GROUP BY NE.mover, NE.path, ASSC.id, US.InstanceID HAVING COUNT(*) = 1 ORDER BY NE.mover, NE.path) AS foo);"
echo
echo More than 1 association
psql -d uemcpdb -U uem_cp_usr -c "SELECT NASExport_mover, NASExport_path, cnt AS Number_of_Associations FROM (SELECT NE.mover AS NASExport_mover, NE.path AS NASExport_path, ASSC.id AS assocID, US.InstanceID AS NFSShare_InstanceID, COUNT(*) AS cnt FROM uem_cp.emc_uem_uasnfsshareleaf AS US, uem_cp.emc_uem_uasnfsshareidentityassocleaf AS ASSC, uem_cp.cimnas_export AS NE WHERE ASSC.sameelementinstancename = TEXTCAT('root/emc:EMC_UEM_UASNFSShareLeaf%InstanceID=', US.InstanceID) AND ASSC.systemelementinstancename = TEXTCAT(TEXTCAT(TEXTCAT('emc/cimnas:CIMNAS_Export%mover=', NE.mover), '%path='), NE.path) GROUP BY NE.mover, NE.path, ASSC.id, US.InstanceID HAVING COUNT(*) > 1 ORDER BY NE.mover, NE.path) AS foo;"
echo
echo Restores integer keys using InstanceName keys
echo Can be used if there are Non-associated NAS Shares by internal integer keys and no Non-associated NAS Shares by InstanceName keys
echo "UPDATE uem_cp.emc_uem_uasnfsshareidentityassocleaf AS ASSC SET systemelementid = NE.id, sameelementid = US.id FROM uem_cp.emc_uem_uasnfsshareleaf AS US, uem_cp.cimnas_export AS NE WHERE ASSC.sameelementinstancename = TEXTCAT('root/emc:EMC_UEM_UASNFSShareLeaf%InstanceID=', US.InstanceID) AND ASSC.systemelementinstancename = TEXTCAT(TEXTCAT(TEXTCAT('emc/cimnas:CIMNAS_Export%mover=', NE.mover), '%path='), NE.path);"
echo  
	  
echo -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
echo "36. NAS shares associated with UAS CIFS shares (1"
echo
echo "NASShare 1:1 ---- UASCIFSShareIdentityAssocLeaf ----- > 1:1 UASCIFSShare"
echo
echo Non-associated NAS Shares by internal integer keys
psql -d uemcpdb -U uem_cp_usr -c "SELECT id AS cimnas_share_id FROM uem_cp.cimnas_share EXCEPT (SELECT foo.expid AS cimnas_share_id FROM (SELECT US.id AS shareid, ASSC.id AS assocID, NE.id AS expid, COUNT(*) AS cnt FROM uem_cp.emc_uem_uascifsshareleaf AS US, uem_cp.emc_uem_uascifsshareidentityassocleaf AS ASSC, uem_cp.cimnas_share AS NE WHERE US.id = ASSC.sameelementid AND NE.id = ASSC.systemelementid AND ASSC.sameelementtype = 'root/emc:EMC_UEM_UASCIFSShareLeaf' GROUP BY US.id, ASSC.id, NE.id HAVING COUNT(*) = 1 ORDER BY US.id, NE.id) AS foo);"
echo
echo Non-associated NAS Shares by InstanceName keys
psql -d uemcpdb -U uem_cp_usr -c "SELECT mover AS Share_mover, name AS Share_name, server AS Share_CIFSServer FROM uem_cp.cimnas_share EXCEPT (SELECT Share_mover, Share_name, Share_CIFSServer FROM (SELECT CS.mover AS Share_mover, CS.name AS Share_name, CS.server AS Share_CIFSServer, ASSC.id AS assocID, US.InstanceID AS CIFSShare_InstanceID, COUNT(*) AS cnt FROM uem_cp.emc_uem_uascifsshareleaf AS US, uem_cp.emc_uem_uascifsshareidentityassocleaf AS ASSC, uem_cp.cimnas_share AS CS WHERE ASSC.sameelementinstancename = TEXTCAT('root/emc:EMC_UEM_UASCIFSShareLeaf%InstanceID=', US.InstanceID) AND ASSC.systemelementinstancename = TEXTCAT(TEXTCAT(TEXTCAT(TEXTCAT(TEXTCAT('emc/cimnas:CIMNAS_Share%mover=', CS.mover), '%name='), CS.name), '%server='), CS.server) GROUP BY CS.mover, CS.name, CS.server, ASSC.id, US.InstanceID HAVING COUNT(*) = 1 ORDER BY CS.mover, CS.name, CS.server) AS foo);"
echo
echo More than 1 association
psql -d uemcpdb -U uem_cp_usr -c "SELECT Share_mover, Share_name, Share_CIFSServer, cnt AS Number_of_Associations FROM (SELECT CS.mover AS Share_mover, CS.name AS Share_name, CS.server AS Share_CIFSServer, ASSC.id AS assocID, US.InstanceID AS CIFSShare_InstanceID, COUNT(*) AS cnt FROM uem_cp.emc_uem_uascifsshareleaf AS US, uem_cp.emc_uem_uascifsshareidentityassocleaf AS ASSC, uem_cp.cimnas_share AS CS WHERE ASSC.sameelementinstancename = TEXTCAT('root/emc:EMC_UEM_UASCIFSShareLeaf%InstanceID=', US.InstanceID) AND ASSC.systemelementinstancename = TEXTCAT(TEXTCAT(TEXTCAT(TEXTCAT(TEXTCAT('emc/cimnas:CIMNAS_Share%mover=', CS.mover), '%name='), CS.name), '%server='), CS.server) GROUP BY CS.mover, CS.name, CS.server, ASSC.id, US.InstanceID HAVING COUNT(*) > 1 ORDER BY CS.mover, CS.name, CS.server) AS foo;"
echo
echo Restores integer keys using InstanceName keys
echo Can be used if there are Non-associated NAS Shares by internal integer keys and no Non-associated NAS Shares by InstanceName keys
echo "UPDATE uem_cp.emc_uem_uascifsshareidentityassocleaf AS ASSC SET systemelementid = CS.id, sameelementid = US.id FROM uem_cp.emc_uem_uascifsshareleaf AS US, uem_cp.cimnas_share AS CS WHERE ASSC.sameelementinstancename = TEXTCAT('root/emc:EMC_UEM_UASCIFSShareLeaf%InstanceID=', US.InstanceID) AND ASSC.systemelementinstancename = TEXTCAT(TEXTCAT(TEXTCAT(TEXTCAT(TEXTCAT('emc/cimnas:CIMNAS_Share%mover=', CS.mover), '%name='), CS.name), '%server='), CS.server);"
echo

echo -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
echo "37. NFS shares have association(s) with IPProtocolEndpoint (1"
echo
echo "UASNFSShare 0:N ---- UASNFSHostAssocLeaf -----> 0:N IPProtocolEndpoint"
echo
echo Non-associated NFS Shares by internal integer keys
psql -d uemcpdb -U uem_cp_usr -c "SELECT id AS uasnfsshare_id FROM uem_cp.emc_uem_uasnfsshareleaf EXCEPT (SELECT DISTINCT foo.shareid AS uasnfsshare_id FROM (SELECT US.id AS shareid, ASSC.id AS assocID, COUNT(*) AS cnt FROM uem_cp.emc_uem_uasnfsshareleaf AS US, uem_cp.emc_uem_uasnfshostassocleaf AS ASSC WHERE US.id = ASSC.antecedentid AND ASSC.antecedenttype = 'root/emc:EMC_UEM_UASNFSShareLeaf' GROUP BY US.id, ASSC.id HAVING COUNT(*) = 1 ORDER BY US.id) AS foo);"
echo
echo Non-associated NFS Shares by InstanceName keys
psql -d uemcpdb -U uem_cp_usr -c "SELECT InstanceID AS uasnfsshare_instanceid FROM uem_cp.emc_uem_uasnfsshareleaf EXCEPT (SELECT DISTINCT uasnfsshare_instanceid FROM (SELECT US.InstanceID AS uasnfsshare_instanceid, ASSC.dependentinstancename AS IPEndpoint, COUNT(*) AS cnt FROM uem_cp.emc_uem_uasnfsshareleaf AS US, uem_cp.emc_uem_uasnfshostassocleaf AS ASSC WHERE ASSC.antecedentinstancename = TEXTCAT('root/emc:EMC_UEM_UASNFSShareLeaf%InstanceID=', US.InstanceID) GROUP BY US.InstanceID, ASSC.dependentinstancename HAVING COUNT(*) = 1 ORDER BY US.InstanceID) AS foo);"
echo
echo More than 1 association with the same IPProtocolEndpoint
psql -d uemcpdb -U uem_cp_usr -c "SELECT uasnfsshare_instanceid, cnt AS Number_of_Associations FROM (SELECT US.InstanceID AS uasnfsshare_instanceid, ASSC.dependentinstancename AS IPEndpoint, COUNT(*) AS cnt FROM uem_cp.emc_uem_uasnfsshareleaf AS US, uem_cp.emc_uem_uasnfshostassocleaf AS ASSC WHERE ASSC.antecedentinstancename = TEXTCAT('root/emc:EMC_UEM_UASNFSShareLeaf%InstanceID=', US.InstanceID) GROUP BY US.InstanceID, ASSC.dependentinstancename HAVING COUNT(*) > 1 ORDER BY US.InstanceID) AS foo;"
echo

echo -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
echo "38. Applications of types GenericStorage, VNwareVMFS, HyperV, Exchange have association(s) with StorageHardwareID (1"
echo
echo "UASApplication 0:N ---- UASiSCSIHostAssocLeaf -----> 0:N StorageHardwareID"
echo
echo "Non-associated UAS Applications by internal integer keys (Warning)"
psql -d uemcpdb -U uem_cp_usr -c "SELECT id AS uasapplication_id FROM uem_cp.emc_uem_uasapplicationleaf WHERE applicationtype NOT IN ('com.emc.uem.application.sharedfolder', 'com.emc.uem.application.vmwarefs') EXCEPT (SELECT DISTINCT foo.appid AS uasapplication_id FROM (SELECT APP.id AS appid, ASSC.id AS assocID, COUNT(*) AS cnt FROM uem_cp.emc_uem_uasapplicationleaf AS APP, uem_cp.emc_uem_uasiscsihostassocleaf AS ASSC WHERE APP.id = ASSC.antecedentid AND ASSC.antecedenttype = 'root/emc:EMC_UEM_UASApplicationLeaf' GROUP BY APP.id, ASSC.id HAVING COUNT(*) = 1 ORDER BY APP.id) AS foo);"
echo
echo "Non-associated UAS Applications by InstanceName keys (Warning)"
psql -d uemcpdb -U uem_cp_usr -c "SELECT InstanceID AS uasapplication_instanceid FROM uem_cp.emc_uem_uasapplicationleaf WHERE applicationtype NOT IN ('com.emc.uem.application.sharedfolder', 'com.emc.uem.application.vmwarefs') EXCEPT (SELECT DISTINCT uasapplication_instanceid FROM (SELECT APP.InstanceID AS uasapplication_instanceid, ASSC.dependentinstancename AS iSCSI_IQNhost, COUNT(*) AS cnt FROM uem_cp.emc_uem_uasapplicationleaf AS APP, uem_cp.emc_uem_uasiscsihostassocleaf AS ASSC WHERE ASSC.antecedentinstancename = TEXTCAT('root/emc:EMC_UEM_UASApplicationLeaf%InstanceID=', APP.instanceID) GROUP BY APP.InstanceID, ASSC.dependentinstancename HAVING COUNT(*) = 1 ORDER BY APP.InstanceID) AS foo);"
echo
echo More than 1 association with the same StorageHardwareID
psql -d uemcpdb -U uem_cp_usr -c "SELECT uasapplication_instanceid, cnt AS Number_of_Associations FROM (SELECT APP.InstanceID AS uasapplication_instanceid, ASSC.dependentinstancename AS iSCSI_IQNhost, COUNT(*) AS cnt FROM uem_cp.emc_uem_uasapplicationleaf AS APP, uem_cp.emc_uem_uasiscsihostassocleaf AS ASSC WHERE ASSC.antecedentinstancename = TEXTCAT('root/emc:EMC_UEM_UASApplicationLeaf%InstanceID=', APP.instanceID) GROUP BY APP.InstanceID, ASSC.dependentinstancename HAVING COUNT(*) > 1 ORDER BY APP.InstanceID) AS foo;"

echo "=========================================================== (1"
echo "MR4 Persistence DB Consistency Check finished (1"
