USE pandekths_maindb;
GO
SELECT TOP 20
       qt.text AS 'SP Name',
       ph.query_plan,
       qs.total_worker_time AS 'TotalWorkerTime',
       qs.total_worker_time / qs.execution_count AS 'AvgWorkerTime',
       qs.execution_count AS 'Execution Count',
       qs.max_elapsed_time,
       qs.last_execution_time,
       qs.plan_handle,
       ISNULL(qs.execution_count / DATEDIFF(Second, qs.creation_time, GETDATE()), 0) AS 'Calls/Second',
       ISNULL(qs.total_elapsed_time / qs.execution_count, 0) AS 'AvgElapsedTime',
       qs.max_logical_reads,
       qs.max_logical_writes,
       DATEDIFF(Minute, qs.creation_time, GETDATE()) AS 'Age in Cache'
FROM sys.dm_exec_query_stats AS qs
     CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS qt
     cross apply sys.dm_exec_query_plan(qs.plan_handle) as ph 
WHERE qt.dbid = DB_ID() -- Filter by current database
      AND ((qt.text LIKE '%XXXXXX%')
      or (qt.text like '%YYYYYYYYYYYYY%'))
ORDER BY
         6 DESC;
GO

--Find missing indexes by cost
/*SELECT DB_NAME(database_id) as db,
	avg_total_user_cost * avg_user_impact * (user_seeks + user_scans) as [total cost], 
	avg_total_user_cost, (user_seeks + user_scans + system_scans + system_seeks) as [# queries affected], avg_user_impact as [potential improvement], 	
	statement, equality_columns as [equality key columns], inequality_columns as [inequality key columns], included_columns,
	last_user_seek, last_user_scan, user_seeks, user_scans, system_seeks, system_scans
FROM sys.dm_db_missing_index_group_stats gs 
	JOIN sys.dm_db_missing_index_groups ig on (ig.index_group_handle = gs.group_handle)
	JOIN sys.dm_db_missing_index_details id on (ig.index_handle = id.index_handle)
ORDER BY avg_total_user_cost * avg_user_impact * (user_seeks + user_scans) DESC;
*/
--Find queries with missing indexes for a specific table [change Address to your table name]
--NOTE: Older versions of SQL Server may need to be ./MissingIndexes instead of //MissingIndexes for the CROSS APPLY 
--This query works with SQL Server 2016 & 2017
;WITH XMLNAMESPACES (DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan')    
SELECT 
	stmt.value('(@StatementText)[1]', 'varchar(max)') AS SQL_Text, 
	obj.value('(@Database)[1]', 'varchar(128)') AS DatabaseName, 
	obj.value('(@Schema)[1]', 'varchar(128)') AS SchemaName, 
	obj.value('(@Table)[1]', 'varchar(128)') AS TableName, 
	obj.value('(@Index)[1]', 'varchar(128)') AS IndexName, 
	obj.value('(@IndexKind)[1]', 'varchar(128)') AS IndexKind, 
	query_plan 
FROM sys.dm_exec_cached_plans AS cp 
	CROSS APPLY sys.dm_exec_query_plan(plan_handle) AS qp 
	CROSS APPLY query_plan.nodes('/ShowPlanXML/BatchSequence/Batch/Statements/StmtSimple') AS batch(stmt) 
	CROSS APPLY stmt.nodes('//MissingIndexes/MissingIndexGroup/MissingIndex[@Table = "[Transactions]"]') AS idx(obj) 
OPTION(MAXDOP 1, RECOMPILE);
