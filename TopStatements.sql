-- Top cached queries by Execution Count (SQL Server 2008 R2)  (Query 43) (Query Execution Counts)
-- SQL Server 2008 R2 SP1 and greater only
SELECT TOP (100) qs.execution_count,
	qs.total_rows,
	qs.last_rows,
	qs.min_rows,
	qs.max_rows,
	qs.last_elapsed_time,
	qs.min_elapsed_time,
	qs.max_elapsed_time,
	total_worker_time,
	total_logical_reads,
	SUBSTRING(qt.TEXT, qs.statement_start_offset / 2 + 1, (
			CASE 
				WHEN qs.statement_end_offset = - 1
					THEN LEN(CONVERT(NVARCHAR(MAX), qt.TEXT)) * 2
				ELSE qs.statement_end_offset
				END - qs.statement_start_offset
			) / 2) AS query_text
FROM sys.dm_exec_query_stats AS qs WITH (NOLOCK)
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS qt
ORDER BY qs.execution_count DESC
OPTION (RECOMPILE);

-- Uses several new rows returned columns to help troubleshoot performance problems
-- Top Cached SPs By Execution Count (SQL 2008 R2) (Query 44) (SP Execution Counts)
SELECT TOP (100) p.NAME AS [SP Name],
	qs.execution_count,
	ISNULL(qs.execution_count / DATEDIFF(Minute, qs.cached_time, GETDATE()), 0) AS [Calls/Minute],
	qs.total_worker_time / qs.execution_count AS [AvgWorkerTime],
	qs.total_worker_time AS [TotalWorkerTime],
	qs.total_elapsed_time,
	qs.total_elapsed_time / qs.execution_count AS [avg_elapsed_time],
	qs.cached_time
FROM sys.procedures AS p WITH (NOLOCK)
INNER JOIN sys.dm_exec_procedure_stats AS qs WITH (NOLOCK)
	ON p.[object_id] = qs.[object_id]
WHERE qs.database_id = DB_ID()
ORDER BY qs.execution_count DESC
OPTION (RECOMPILE);

-- Tells you which cached stored procedures are called the most often
-- This helps you characterize and baseline your workload
-- Top Cached SPs By Avg Elapsed Time (SQL 2008 R2)  (Query 45) (SP Avg Elapsed Time) 
SELECT TOP (25) p.NAME AS [SP Name],
	qs.total_elapsed_time / qs.execution_count AS [avg_elapsed_time],
	qs.total_elapsed_time,
	qs.execution_count,
	ISNULL(qs.execution_count / DATEDIFF(Minute, qs.cached_time, GETDATE()), 0) AS [Calls/Minute],
	qs.total_worker_time / qs.execution_count AS [AvgWorkerTime],
	qs.total_worker_time AS [TotalWorkerTime],
	qs.cached_time
FROM sys.procedures AS p WITH (NOLOCK)
INNER JOIN sys.dm_exec_procedure_stats AS qs WITH (NOLOCK)
	ON p.[object_id] = qs.[object_id]
WHERE qs.database_id = DB_ID()
ORDER BY avg_elapsed_time DESC
OPTION (RECOMPILE);

-- This helps you find long-running cached stored procedures that
-- may be easy to optimize with standard query tuning techniques
-- Top Cached SPs By Avg Elapsed Time with execution time variability   (Query 46) (SP Avg Elapsed Variable Time)
SELECT TOP (25) p.NAME AS [SP Name],
	qs.execution_count,
	qs.min_elapsed_time,
	qs.total_elapsed_time / qs.execution_count AS [avg_elapsed_time],
	qs.max_elapsed_time,
	qs.last_elapsed_time,
	qs.cached_time
FROM sys.procedures AS p WITH (NOLOCK)
INNER JOIN sys.dm_exec_procedure_stats AS qs WITH (NOLOCK)
	ON p.[object_id] = qs.[object_id]
WHERE qs.database_id = DB_ID()
ORDER BY avg_elapsed_time DESC
OPTION (RECOMPILE);

-- This gives you some interesting information about the variability in the
-- execution time of your cached stored procedures, which is useful for tuning
-- Top Cached SPs By Total Worker time (SQL 2008 R2). Worker time relates to CPU cost  (Query 47) (SP Worker Time)
SELECT TOP (25) p.NAME AS [SP Name],
	qs.total_worker_time AS [TotalWorkerTime],
	qs.total_worker_time / qs.execution_count AS [AvgWorkerTime],
	qs.execution_count,
	ISNULL(qs.execution_count / DATEDIFF(Minute, qs.cached_time, GETDATE()), 0) AS [Calls/Minute],
	qs.total_elapsed_time,
	qs.total_elapsed_time / qs.execution_count AS [avg_elapsed_time],
	qs.cached_time
FROM sys.procedures AS p WITH (NOLOCK)
INNER JOIN sys.dm_exec_procedure_stats AS qs WITH (NOLOCK)
	ON p.[object_id] = qs.[object_id]
WHERE qs.database_id = DB_ID()
ORDER BY qs.total_worker_time DESC
OPTION (RECOMPILE);

-- This helps you find the most expensive cached stored procedures from a CPU perspective
-- You should look at this if you see signs of CPU pressure
-- Top Cached SPs By Total Logical Reads (SQL 2008 R2). Logical reads relate to memory pressure  (Query 48) (SP Logical Reads)
SELECT TOP (25) p.NAME AS [SP Name],
	qs.total_logical_reads AS [TotalLogicalReads],
	qs.total_logical_reads / qs.execution_count AS [AvgLogicalReads],
	qs.execution_count,
	ISNULL(qs.execution_count / DATEDIFF(Minute, qs.cached_time, GETDATE()), 0) AS [Calls/Minute],
	qs.total_elapsed_time,
	qs.total_elapsed_time / qs.execution_count AS [avg_elapsed_time],
	qs.cached_time
FROM sys.procedures AS p WITH (NOLOCK)
INNER JOIN sys.dm_exec_procedure_stats AS qs WITH (NOLOCK)
	ON p.[object_id] = qs.[object_id]
WHERE qs.database_id = DB_ID()
ORDER BY qs.total_logical_reads DESC
OPTION (RECOMPILE);

-- This helps you find the most expensive cached stored procedures from a memory perspective
-- You should look at this if you see signs of memory pressure
-- Top Cached SPs By Total Physical Reads (SQL 2008 R2). Physical reads relate to disk I/O pressure  (Query 49) (SP Physical Reads)
SELECT TOP (25) p.NAME AS [SP Name],
	qs.total_physical_reads AS [TotalPhysicalReads],
	qs.total_physical_reads / qs.execution_count AS [AvgPhysicalReads],
	qs.execution_count,
	qs.total_logical_reads,
	qs.total_elapsed_time,
	qs.total_elapsed_time / qs.execution_count AS [avg_elapsed_time],
	qs.cached_time
FROM sys.procedures AS p WITH (NOLOCK)
INNER JOIN sys.dm_exec_procedure_stats AS qs WITH (NOLOCK)
	ON p.[object_id] = qs.[object_id]
WHERE qs.database_id = DB_ID()
	AND qs.total_physical_reads > 0
ORDER BY qs.total_physical_reads DESC,
	qs.total_logical_reads DESC
OPTION (RECOMPILE);

-- This helps you find the most expensive cached stored procedures from a read I/O perspective
-- You should look at this if you see signs of I/O pressure or of memory pressure
-- Top Cached SPs By Total Logical Writes (SQL 2008 R2)  (Query 50) (SP Logical Writes)
-- Logical writes relate to both memory and disk I/O pressure 
SELECT TOP (25) p.NAME AS [SP Name],
	qs.total_logical_writes AS [TotalLogicalWrites],
	qs.total_logical_writes / qs.execution_count AS [AvgLogicalWrites],
	qs.execution_count,
	ISNULL(qs.execution_count / DATEDIFF(Second, qs.cached_time, GETDATE()), 0) AS [Calls/Second],
	qs.total_elapsed_time,
	qs.total_elapsed_time / qs.execution_count AS [avg_elapsed_time],
	qs.cached_time
FROM sys.procedures AS p WITH (NOLOCK)
INNER JOIN sys.dm_exec_procedure_stats AS qs WITH (NOLOCK)
	ON p.[object_id] = qs.[object_id]
WHERE qs.database_id = DB_ID()
	AND qs.total_logical_writes > 0
ORDER BY qs.total_logical_writes DESC
OPTION (RECOMPILE);

-- This helps you find the most expensive cached stored procedures from a write I/O perspective
-- You should look at this if you see signs of I/O pressure or of memory pressure
-- Lists the top statements by average input/output usage for the current database  (Query 51) (Top IO Statements)
SELECT TOP (50) OBJECT_NAME(qt.objectid, dbid) AS [SP Name],
	(qs.total_logical_reads + qs.total_logical_writes) / qs.execution_count AS [Avg IO],
	qs.execution_count AS [Execution Count],
	SUBSTRING(qt.[text], qs.statement_start_offset / 2, (
			CASE 
				WHEN qs.statement_end_offset = - 1
					THEN LEN(CONVERT(NVARCHAR(max), qt.[text])) * 2
				ELSE qs.statement_end_offset
				END - qs.statement_start_offset
			) / 2) AS [Query Text]
FROM sys.dm_exec_query_stats AS qs WITH (NOLOCK)
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS qt
WHERE qt.[dbid] = DB_ID()
ORDER BY [Avg IO] DESC
OPTION (RECOMPILE);
	-- Helps you find the most expensive statements for I/O by SP
GO

