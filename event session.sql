--change log file path
CREATE EVENT SESSION
what_queries_are_failing
ON SERVER
ADD EVENT sqlserver.error_reported
(
ACTION (sqlserver.sql_text, sqlserver.tsql_stack, sqlserver.database_id, sqlserver.username)
WHERE ([severity]> 10)
)
ADD TARGET package0.asynchronous_file_target
(set filename = '.\LogFiles\what_queries_are_failing.xel' ,
metadatafile = '.\LogFiles\what_queries_are_failing.xem',
max_file_size = 5,
max_rollover_files = 5)
WITH (MAX_DISPATCH_LATENCY = 5SECONDS)
GO
 
-- Start the session
ALTER EVENT SESSION what_queries_are_failing
ON SERVER STATE = START
GO


-- Stop the session
ALTER EVENT SESSION what_queries_are_failing
ON SERVER STATE = STOP
GO

--change log file path

with events_cte as
(
select
DATEADD(mi,
DATEDIFF(mi, GETUTCDATE(), CURRENT_TIMESTAMP),
xevents.event_data.value('(event/@timestamp)[1]', 'datetime2')) AS [err_timestamp],
xevents.event_data.value('(event/data[@name="severity"]/value)[1]', 'bigint') AS [err_severity],
xevents.event_data.value('(event/data[@name="error_number"]/value)[1]', 'bigint') AS [err_number],
xevents.event_data.value('(event/data[@name="message"]/value)[1]', 'nvarchar(512)') AS [err_message],
xevents.event_data.value('(event/action[@name="sql_text"]/value)[1]', 'nvarchar(max)') AS [sql_text],
xevents.event_data
from sys.fn_xe_file_target_read_file
('.\LogFiles\what_queries_are_failing*.xel',
'.\LogFiles\what_queries_are_failing*.xem',
null, null)
cross apply (select CAST(event_data as XML) as event_data) as xevents
)
SELECT *
from events_cte
order by err_timestamp;

go

--drop event session
drop EVENT SESSION what_queries_are_failing on server
go