@echo off
setlocal enableextensions enabledelayedexpansion
SET /A ARGS_COUNT=0

FOR %%A in (%*) DO SET /A ARGS_COUNT+=1

rem ECHO %ARGS_COUNT%
set args=2
if %ARGS_COUNT% LSS %args% goto usage
rem if %ARGS_COUNT% GTR %args% goto usage

set interval=10
set t=%time:~0,8%
set t=%t::=%
set t=%t: =0%

path=%PATH%;"c:\Program Files (x86)\Java\jre6\bin\java.exe"

set basic=net.basic.inBytes,net.basic.outBytes,store.readBytes,store.writeBytes
set advance=net.device,fs.ufs.name,fs.ufs.findNode,fs.ufs.indirectBlk,store.diskVolume,store.hostBusAdapter,store.ioTimeHist,store.ioTimeHistOver,store.logicalVolume.global.readRequests,store.logicalVolume.global.writeRequests,store.logicalVolume.global.readBytes,store.logicalVolume.global.writeBytes,store.logicalVolume.metaVolume,store.scsiBusDevice,store.totalCalls,fs.ufs.log.activeDescriptors,fs.ufs.log.activeHolds,fs.ufs.log.activeSize,fs.ufs.log.blockedForFlush,fs.ufs.log.bytesWritten,fs.ufs.log.duplicateObjects,fs.ufs.log.peakActiveDescriptors,fs.ufs.log.peakActiveHolds,fs.ufs.log.peakActiveSize,fs.ufs.log.recordsWritten,fs.ufs.log.staging.delayedWrites,fs.ufs.log.staging.efficiency,fs.ufs.log.staging.immediateWrites,fs.ufs.log.staging.savedWrites,fs.ufs.log.staging.totalWrites,fs.ufs.log.transaction
set cifs=cifs.clientOS,cifs.clientOS.ALL-ELEMENTS.connections,cifs.global.basic.reads,cifs.global.basic.writes,cifs.global.basic.totalCalls,cifs.global.basic.readBytes,cifs.global.basic.writeBytes,cifs.global.basic.readAvgSize,cifs.global.basic.writeAvgSize,cifs.global.usage.currentConnections,cifs.global.usage.currentOpenFiles,cifs.global.usage.currentTcpConnections,cifs.global.usage.currentThreads,cifs.global.usage.currentUsers,cifs.smb1.basic.reads,cifs.smb1.basic.writes,cifs.smb1.basic.totalCalls,cifs.smb1.basic.readBytes,cifs.smb1.basic.writeBytes,cifs.smb1.basic.readAvgSize,cifs.smb1.basic.writeAvgSize,cifs.smb1.op,cifs.smb1.totalCalls,cifs.smb1.trans2,cifs.smb1.trans2TotalCalls,cifs.smb1.transNT,cifs.smb1.transNTTotalCalls,cifs.smb1.usage.currentConnections,cifs.smb1.usage.currentOpenFiles,cifs.smb1.usage.currentTcpConnections,cifs.smb1.usage.currentThreads,cifs.smb1.usage.currentUsers,cifs.smb2.basic.reads,cifs.smb2.basic.writes,cifs.smb2.basic.totalCalls,cifs.smb2.basic.readBytes,cifs.smb2.basic.writeBytes,cifs.smb2.basic.readAvgSize,cifs.smb2.basic.writeAvgSize,cifs.smb2.ioctl,cifs.smb2.ioctlTotalCalls,cifs.smb2.op,cifs.smb2.queryInfo,cifs.smb2.queryInfoTotalCalls,cifs.smb2.setInfo,cifs.smb2.setInfoTotalCalls,cifs.smb2.totalCalls,cifs.smb2.usage.currentConnections,cifs.smb2.usage.currentOpenFiles,cifs.smb2.usage.currentTcpConnections,cifs.smb2.usage.currentThreads,cifs.clientOS.ALL-ELEMENTS.connections,cifs.global.basic.reads,cifs.global.basic.writes,cifs.global.basic.totalCalls,cifs.global.basic.readBytes,cifs.global.basic.writeBytes,cifs.global.basic.readAvgSize,cifs.global.basic.writeAvgSize,cifs.global.usage.currentConnections,cifs.global.usage.currentOpenFiles,cifs.global.usage.currentTcpConnections,cifs.global.usage.currentThreads,cifs.global.usage.currentUsers,cifs.smb1.basic.reads,cifs.smb1.basic.writes,cifs.smb1.basic.totalCalls,cifs.smb1.basic.readBytes,cifs.smb1.basic.writeBytes,cifs.smb1.basic.readAvgSize,cifs.smb1.basic.writeAvgSize,cifs.smb1.op,cifs.smb1.totalCalls,cifs.smb1.trans2,cifs.smb1.trans2TotalCalls,cifs.smb1.transNT,cifs.smb1.transNTTotalCalls,cifs.smb1.usage.currentConnections,cifs.smb1.usage.currentOpenFiles,cifs.smb1.usage.currentTcpConnections,cifs.smb1.usage.currentThreads,cifs.smb1.usage.currentUsers,cifs.smb2.basic.reads,cifs.smb2.basic.writes,cifs.smb2.basic.totalCalls,cifs.smb2.basic.readBytes,cifs.smb2.basic.writeBytes,cifs.smb2.basic.readAvgSize,cifs.smb2.basic.writeAvgSize,cifs.smb2.ioctl,cifs.smb2.ioctlTotalCalls,cifs.smb2.op,cifs.smb2.queryInfo,cifs.smb2.queryInfoTotalCalls,cifs.smb2.setInfo,cifs.smb2.setInfoTotalCalls,cifs.smb2.totalCalls,cifs.smb2.usage.currentConnections,cifs.smb2.usage.currentOpenFiles,cifs.smb2.usage.currentTcpConnections,cifs.smb2.usage.currentThreads,cifs.smb2.usage.currentUsers
set nfs=nfs.avgTime,nfs.badReadStreams,nfs.basic.reads,nfs.basic.writes,nfs.basic.readBytes,nfs.basic.writeBytes,nfs.basic.readAvgSize,nfs.basic.writeAvgSize,nfs.currentThreads,nfs.gssXid.drops,nfs.gssXid.droppedRequests,nfs.gssXid.forwards,nfs.gssXid.inProg,nfs.gssXid.inProgHits,nfs.gssXid.misses,nfs.gssXid.reDos,nfs.gssXid.reForwards,nfs.gssXid.reSentReplies,nfs.gssXid.lookups,nfs.maxUsedThreads,nfs.readStreamTime,nfs.totalCalls,nfs.v2.io,nfs.v2.op,nfs.v2.totalCalls,nfs.v2.totalFailures,nfs.v2.totalTime,nfs.v3.io,nfs.v3.op,nfs.v3.totalCalls,nfs.v3.totalFailures,nfs.v3.totalTime,nfs.v3.vstorage,nfs.v4.io,nfs.v4.op,nfs.v4.totalCalls,nfs.v4.totalFailures,nfs.v4.totalTime,nfs.writeStreamTime,nfs.xid.drops,nfs.xid.droppedRequests,nfs.xid.forwards,nfs.xid.inProg,nfs.xid.inProgHits,nfs.xid.misses,nfs.xid.reDos,nfs.xid.reForwards,nfs.xid.reSentReplies,nfs.xid.lookups
set iscsi=iscsi.basic.reads,iscsi.basic.readFailures,iscsi.basic.writes,iscsi.basic.writeFailures,iscsi.basic.readBytes,iscsi.basic.writeBytes,iscsi.basic.totalReads,iscsi.basic.totalWrites,iscsi.basic.totalCalls,iscsi.basic.totalBytes,iscsi.basic.readAvgSize,iscsi.basic.writeAvgSize,iscsi.basic.ioAvgSize,iscsi.lun,iscsi.target
set network=net.ip.tcp.ackHeaderPredicts,net.ip.tcp.checksumErrors,net.ip.tcp.checksumOffloadErrors,net.ip.tcp.connectionAccepts,net.ip.tcp.connectionAttempts,net.ip.tcp.connectionCloses,net.ip.tcp.connectionDrops,net.ip.tcp.connectionEmbryonicDrops,net.ip.tcp.connectionKeepAliveDrops,net.ip.tcp.connectionRetransmitTimeoutDrops,net.ip.tcp.connections,net.ip.tcp.dataHeaderPredicts,net.ip.tcp.delayedAcks,net.ip.tcp.inAckBytes,net.ip.tcp.inAcks,net.ip.tcp.inAfterClose,net.ip.tcp.inAfterWindow,net.ip.tcp.inAfterWindowBytes,net.ip.tcp.inDuplicateAcks,net.ip.tcp.inDuplicateBytes,net.ip.tcp.inDuplicates,net.ip.tcp.inExcessAcks,net.ip.tcp.inInSequenceBytes,net.ip.tcp.inInSequences,net.ip.tcp.inOffsetErrors,net.ip.tcp.inOutOfOrderBytes,net.ip.tcp.inOutoOfOrder,net.ip.tcp.inPackets,net.ip.tcp.inPartDuplicates,net.ip.tcp.inSacks,net.ip.tcp.inShorts,net.ip.tcp.inUnsupportedIpVersionErrors,net.ip.tcp.inWindowProbes,net.ip.tcp.inWindowUpdates,net.ip.tcp.keepAliveTimeouts,net.ip.tcp.outAcks,net.ip.tcp.outControls,net.ip.tcp.outDataPackets,net.ip.tcp.outKeepAliveProbes,net.ip.tcp.outPackets,net.ip.tcp.outPartialAckRetransmits,net.ip.tcp.outProbes,net.ip.tcp.outSacks,net.ip.tcp.outUrgents,net.ip.tcp.outWindowsUpdates,net.ip.tcp.partDuplicateBytes,net.ip.tcp.retransmitBytes,net.ip.tcp.retransmitTimeouts,net.ip.tcp.retransmits,net.ip.tcp.roundTripTime,net.ip.tcp.timedPackets,net.ip.udp.badIpv6Addresss,net.ip.udp.checksumErrors,net.ip.udp.checksumOffloadErrors,net.ip.udp.drops,net.ip.udp.fullSockets,net.ip.udp.headerErrors,net.ip.udp.inErrors,net.ip.udp.inPackets,net.ip.udp.ipVersionErrors,net.ip.udp.lengthErrors,net.ip.udp.outPackets



set all=%basic%,%advance%,%cifs%,%nfs%,%iscsi%,%network%
set stats=%basic%

set server=%1
shift
set dart_ip=%1
shift


:loop
FOR %%a IN (%*) DO (
  IF /I "%%a"=="advance" SET stats=!stats!,%advance%
  IF /I "%%a"=="cifs" SET stats=!stats!,%cifs%
  IF /I "%%a"=="nfs" SET stats=!stats!,%nfs%
  IF /I "%%a"=="iscsi" SET stats=!stats!,%iscsi%
  IF /I "%%a"=="network" SET  stats=!stats!,%network%
  IF /I "%%a"=="all" SET  stats=%all%  & GOTO execute
  )


:execute
echo "java.exe -Xmx256M -cp server_stats.jar server_stats %dart_ip% -vis eng -m !stats! -i %interval% -format csv -SLIM > %server%_%date:~4,2%%date:~7,2%%date:~10,4%_%t%.csv"
java.exe -Xmx256M -cp server_stats.jar server_stats %dart_ip% -vis eng -m !stats! -i %interval% -format csv -SLIM > %server%_%date:~4,2%%date:~7,2%%date:~10,4%_%t%.csv


:usage
echo.
echo Usage :server_stats.bat server_2/3 VNXe_server_IP stat_set1,stat_set2,stat_set3,stat_set4
echo.
echo stat_set option : cifs,nfs,iscsi,network,advance,all 
echo.
echo.
echo eg1 server_stats.bat server_3 192.168.3.86 (default is basic stats)
echo. 
echo eg2 server_stats.bat server_2 192.168.3.86 cifs,nfs,iscsi
echo.
echo eg3 server_stats.bat server_3 192.168.3.86 all
echo.

