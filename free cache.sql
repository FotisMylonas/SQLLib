use master
go
DBCC DROPCLEANBUFFERS
go
DBCC FREEPROCCACHE 
go
DBCC FREESESSIONCACHE
go
DBCC FREESYSTEMCACHE ('ALL') WITH MARK_IN_USE_FOR_REMOVAL;
go