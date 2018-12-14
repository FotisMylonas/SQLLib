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
      AND ((qt.text LIKE '%XXXXXXXXXXXX%')
      or (qt.text like '%YYYYYYYYYYY%'))
ORDER BY
         6 DESC;
GO