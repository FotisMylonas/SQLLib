
DECLARE @DateTo DATE = DATEADD(dd, 1, getdate());
DECLARE @DateFrom DATE = DATEADD(dd, - 3, @DateTo);

SELECT @DateFrom,
	@DateTo;

WITH a
AS (
	SELECT CAST(XEventData.XEvent.value('(data/value)[1]', 'varchar(max)') AS XML) AS DeadlockGraph
	FROM (
		SELECT CAST(target_data AS XML) AS TargetData
		FROM sys.dm_xe_session_targets st
		JOIN sys.dm_xe_sessions s
			ON s.address = st.event_session_address
		WHERE [name] = 'system_health'
		) AS Data
	CROSS APPLY TargetData.nodes('//RingBufferTarget/event') AS XEventData(XEvent)
	WHERE XEventData.XEvent.value('@name', 'varchar(4000)') = 'xml_deadlock_report'
	),
executionStackint
AS (
	SELECT sqlhandle = convert(VARBINARY(64), T.c.value('(./@sqlhandle)[1]', 'varchar(128)'), 1),
		stmtstart = T.c.value('(./@stmtstart)[1]', 'int'),
		stmtend = T.c.value('(./@stmtend)[1]', 'int'),
		processid = T.c.value('(./@id)[1]', 'nvarchar(500)')
	FROM a
	CROSS APPLY a.DeadlockGraph.nodes('//deadlock/process-list/process/executionStack/frame') AS T(c)
	),
executionStack
AS (
	SELECT i.sqlhandle,
		i.stmtstart,
		i.stmtend,
		i.processid,
		est.TEXT AS RawText
	FROM executionStackint i
	CROSS APPLY sys.dm_exec_sql_text(i.sqlhandle) AS est
	),
processlist
AS (
	SELECT id = T.c.value('(./@id)[1]', 'nvarchar(500)'),
		lockMode = T.c.value('(./@lockMode)[1]', 'nvarchar(50)'),
		transactionname = T.c.value('(./@transactionname)[1]', 'nvarchar(500)'),
		lasttranstarted = T.c.value('(./@lasttranstarted)[1]', 'datetime'),
		lastbatchstarted = T.c.value('(./@lastbatchstarted)[1]', 'datetime'),
		lastbatchcompleted = T.c.value('(./@lastbatchcompleted)[1]', 'datetime'),
		clientapp = T.c.value('(./@clientapp)[1]', 'int'),
		hostname = T.c.value('(./@hostname)[1]', 'nvarchar(500)'),
		loginname = T.c.value('(./@loginname)[1]', 'nvarchar(500)'),
		isolationlevel = T.c.value('(./@isolationlevel)[1]', 'nvarchar(100)'),
		currentdb = T.c.value('(./@currentdb)[1]', 'int')
	FROM a
	CROSS APPLY a.DeadlockGraph.nodes('//deadlock/process-list/process') AS T(c)
	),
ownerlist
AS (
	SELECT sqlhandle = convert(VARBINARY(64), T.c.value('(./@sqlhandle)[1]', 'varchar(128)'), 1),
		ownerid = T.c.value('(./@id)[1]', 'nvarchar(500)'),
		ownermode = T.c.value('(./@mode)[1]', 'nvarchar(50)'),
		associatedObjectId = T.c.value('(../../@associatedObjectId)[1]', 'bigint'),
		ridlockmode = T.c.value('(../../@mode)[1]', 'nvarchar(50)')
	FROM a
	CROSS APPLY a.DeadlockGraph.nodes('//deadlock/resource-list/ridlock/owner-list/owner') AS T(c)
	),
waiterlist
AS (
	SELECT waiterid = T.c.value('(./@id)[1]', 'nvarchar(500)'),
		waitermode = T.c.value('(./@mode)[1]', 'nvarchar(50)'),
		requestType = T.c.value('(./@requestType)[1]', 'nvarchar(50)'),
		associatedObjectId = T.c.value('(../../@associatedObjectId)[1]', 'bigint'),
		ridlockmode = T.c.value('(../../@mode)[1]', 'nvarchar(50)')
	FROM a
	CROSS APPLY a.DeadlockGraph.nodes('//deadlock/resource-list/ridlock/waiter-list/waiter') AS T(c)
	)
SELECT DB_NAME(currentdb) AS [Database],
	cte.id,
	CTE.lasttranstarted,
	CTE.lastbatchstarted,
	CTE.lastbatchcompleted,
	executionStack.stmtstart,
	executionStack.stmtend,
	CTE.lockMode,
	CTE.hostname,
	CTE.loginname,
	CTE.isolationlevel,
	/*substring(est.TEXT, executionStack.stmtstart / 2, CASE 
			WHEN executionStack.stmtend IS NOT NULL
				THEN (executionStack.stmtend - executionStack.stmtstart) / 2
			ELSE len(est.TEXT)
			END) AS stmt,*/
	executionStack.RawText,
	olist.ownerid AS ownerid,
	olist.ownermode,
	olist.ridlockmode,
	olist.associatedObjectId,
	relatedobjects.objectname,
	relatedobjects.objectid,
	waiterlist.waitermode,
	waiterlist.requestType,
	waiterlist.ridlockmode
FROM processlist CTE
INNER JOIN executionStack executionStack
	ON executionStack.processid = cte.id
LEFT OUTER JOIN ownerlist olist
	ON olist.ownerid = cte.id
OUTER APPLY (
	SELECT s.object_id AS objectid,
		isnull(SCHEMA_NAME(s.schema_id) + '.', '') + isnull(s.NAME, '') AS objectname
	FROM sys.objects s
	INNER JOIN sys.partitions p
		ON p.object_id = s.object_id
	WHERE p.partition_id = olist.associatedObjectId
	
	UNION
	
	SELECT i.object_id,
		isnull(OBJECT_NAME(i.object_id), '') + isnull('.' + i.NAME, '') AS objectname
	FROM sys.partitions AS p
	INNER JOIN sys.indexes AS i
		ON i.object_id = p.object_id
			AND i.index_id = p.index_id
	WHERE p.partition_id = olist.associatedObjectId
	) AS relatedobjects
LEFT OUTER JOIN waiterlist waiterlist
	ON waiterlist.waiterid = cte.id
WHERE (
		(
			CTE.lasttranstarted >= @DateFrom
			AND CTE.lasttranstarted < @DateTo
			)
		OR (
			CTE.lastbatchstarted >= @DateFrom
			AND CTE.lastbatchstarted < @DateTo
			)
		OR (
			CTE.lastbatchcompleted >= @DateFrom
			AND CTE.lastbatchcompleted < @DateTo
			)
		)
GO


