/*

Name: ProcessSample.sql
Author: Joe Giordano
Date Created: June 6th, 2013
Purpose: To summarize a server-side trace
----------------------------------------------------------------------------------------------------
The MIT License (MIT)

Copyright (c) 2013 Joe Giordano

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
----------------------------------------------------------------------------------------------------





Updates:
--------
Test


*/

-- NOCOUNT
SET NOCOUNT ON

-- Database selection
Print 'Switching to TraceData database...'
GO
USE TraceData
GO

-- Drop old work table
Print 'Drop old work table...'
GO
drop table alltrace
GO

-- Populate work table from files.  The filename and number of files have to be hard-coded.
Print 'Populate work table from files...'
GO
select * into alltrace from fn_trace_gettable('H:\Traces\All\Extract\AllJun12.20.trc', 48)
GO

-- Drop temptrace indexes, we can fill the table faster.
Print 'Dropping indexes...'
GO
drop index temptrace.IX_StartTime
go
drop index temptrace.IX_Duration
go
drop index temptrace.IX_DBName
go

-- Populate temptrace table for processing, changing TextData column to varchar(8000)
Print 'Populating temptrace table...'
GO
truncate table temptrace
GO
INSERT INTO TempTrace
           ([EventClass]
           ,[TextData]
           ,[ApplicationName]
           ,[NTUserName]
           ,[LoginName]
           ,[CPU]
           ,[Reads]
           ,[Writes]
           ,[Duration]
           ,[ClientProcessID]
           ,[SPID]
           ,[StartTime]
           ,[EndTime]
           ,[BinaryData]
           ,[HostName]
		   ,[DatabaseName])
SELECT [EventClass]
      ,CONVERT(varchar(8000), [TextData]) AS [TextData]
      ,[ApplicationName]
      ,[NTUserName]
      ,[LoginName]
      ,[CPU]
      ,[Reads]
      ,[Writes]
      ,[Duration]
      ,[ClientProcessID]
      ,[SPID]
      ,[StartTime]
      ,[EndTime]
      ,[BinaryData]
      ,[HostName]
	  ,[DatabaseName]
  FROM dbo.alltrace

-- Apply indexes
Print 'Applying indexes...'
GO
create nonclustered index IX_StartTime on temptrace(starttime)
go
create nonclustered index IX_Duration on temptrace(duration)
go
create nonclustered index IX_DBName on temptrace(DatabaseName)
go

-- Display capture information
Print 'Capture Information:'
GO
select MIN(starttime) as [MinStart], MAX(starttime) as [MaxStart] from temptrace
GO
select DATEDIFF(minute, min(starttime), max(EndTime)) AS [Minutes] from temptrace
GO
select COUNT(*) as [CountFromTempTrace] from temptrace
GO

-- Get all queries above 2 seconds duration
Print 'All queries above 2 second threshold...'
GO
select starttime, endtime, textdata, (cast(duration as decimal(18,2)) / 1000000) as [Duration(sec)], Reads, Writes, CPU, LoginName
from temptrace
where Duration > 2000000
and loginname like '%WebUser'
order by Duration desc
GO

-- Show all queries (left 3000 characters) and their call count
Print 'All queries call count above 1000 calls...'
GO
select top 20 left(textdata, 3000) as [Command 3000 chr], ApplicationName, count(*) as theCount
from temptrace
--where databasename = 'StickyFish'
group by left(textdata, 3000), ApplicationName
having count(*) > 1000
order by count(*) desc
GO

-- Show all databases and their call counts
Print 'Call counts by database name...'
GO
select top 50 DatabaseName, count(*) as NumCalls
from temptrace
where DatabaseName is not null
group by databasename
order by DatabaseName

-- Show all call counts by hostname
Print 'Call counts by host name...'
GO
select hostname, COUNT(*) as NumCalls
from temptrace
where HostName is not null
group by HostName
order by HostName
GO

-- Estimate 24 hour call count by host name
Print 'Estimate 24 hour call count by host name...'
GO
select HostName, COUNT(*) as [Calls5Minutes],
		(COUNT(*) * 12) as [CallsOneHour],
		(COUNT(*) * 12) * 24 as [Calls24Hours]
from temptrace
where HostName is not null
group by HostName
-- with rollup
order by HostName
GO

-- Estimate 24 hour call count by login
Print 'Estimate 24 hour call count by login...'
GO
select LoginName, COUNT(*) as [Calls5Minutes],
		(COUNT(*) * 12) as [CallsOneHour],
		(COUNT(*) * 12) * 24 as [Calls24Hours]
from temptrace
where LoginName is not null
group by LoginName
-- with rollup
order by LoginName
GO
