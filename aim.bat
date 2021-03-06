REM ---------------------------------------
REM This bat:
REM     1) Deletes existing dsability file
REM     2) Receive AIM disability file and send to BANDEVLDB
REM     3) Execute aim_to_banner sql which inserts AIMS data to CC Banner
REM Execute SZPDISA stored procedure
REM ---------------------------------------

echo on

date /t
time /t

d:

cd \

cd app\Banr\local\aim\AimToBanner

REM -------------------------------------
REM Set Variables
REM -------------------------------------

set AIMFILE=disabilityIDs.txt


REM -------------------------------------
REM Delete prior AIM files on BANJOT
REM -------------------------------------

del d:\app\Banr\local\aim\AimToBanner\%AIMFILE%


REM -------------------------------------
REM Set SFTP credentials
REM -------------------------------------

set SFTPUSER=Coloradocollege
set SFTPPASS=password
set SFTPHOST=169.54.207.228
set SFTPPORT=22


REM -------------------------------------------------
REM Receive AIM disability file and send to BANDEVLDB
REM -------------------------------------------------

C:\pscp\pscp.exe -sftp -P %SFTPPORT% -pw %SFTPPASS% %SFTPUSER%@%SFTPHOST%:%AIMFILE% %AIMFILE%
REM copy disabilityIDs.txt \\bandevldb\d$\External_Tables\%AIMFILE%
copy disabilityIDs.txt \\bantestrepdb\d$\External_Tables\%AIMFILE%


REM --------------------------------------------------------------
REM Execute aim_to_banner sql which inserts AIMS data to CC Banner
REM --------------------------------------------------------------

REM call baninst1_sql aim_to_banner
Sqlplus /@TESTREP_BANINST1 @aim_to_banner

date /t
time /t