DECLARE @ts_now BIGINT=
(
    SELECT
           cpu_ticks / (cpu_ticks / ms_ticks)
    FROM sys.dm_os_sys_info
);
SELECT
       SQLProcessUtilization AS [SQL Server Process CPU Utilization],
       SystemIdle AS [System Idle Process],
       100 - SystemIdle - SQLProcessUtilization AS [Other Process CPU Utilization],
       [Event Time],
       [Action],
       [State],
       [DoomReason],
       [Address] AS appdomain_address,
       appdomain_name,
       [DbId],
       [record]
FROM
(
    SELECT
           ring_buffer_address,
           ring_buffer_type,
           [timestamp],
           DATEADD(ms, -1 * (@ts_now - [timestamp]), GETDATE()) AS [Event Time],
           [record],
           record.value('(./Record/@id)[1]', 'int') AS record_id,
           record.value('(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]', 'int') AS [SystemIdle],
           record.value('(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]', 'int') AS [SQLProcessUtilization],
           record.value('(./Record/Action)[1]', 'nvarchar(100)') AS [Action],
           record.value('(./Record/AppDomain/State)[1]', 'nvarchar(100)') AS [State],
           record.value('(./Record/AppDomain/DoomReason)[1]', 'nvarchar(1000)') AS [DoomReason],
           record.value('(./Record/AppDomain/@address)[1]', 'nvarchar(1000)') AS [Address],
           record.value('(./Record/AppDomain/@dbId)[1]', 'int') AS [DbId]
    FROM
(
    SELECT
           r.ring_buffer_address,
           r.ring_buffer_type,
           r.[timestamp],
           CONVERT(XML, r.record) AS [record]
    FROM sys.dm_os_ring_buffers r
    WHERE ring_buffer_type = N'RING_BUFFER_CLRAPPDOMAIN'
) AS x
) AS y
OUTER APPLY
(
    SELECT TOP 1
           dm_clr_appdomains.appdomain_name
    FROM sys.dm_clr_appdomains dm_clr_appdomains
    WHERE dm_clr_appdomains.db_id = DbId
          AND dm_clr_appdomains.appdomain_address = appdomain_address
) [appdomain]
ORDER BY
         record_id ASC;
GO
