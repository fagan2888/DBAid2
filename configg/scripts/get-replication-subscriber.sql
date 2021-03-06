SET NOCOUNT ON;

SELECT 'HADR' AS [heading], 'Replication' AS [subheading], '**Subscribers**' AS [comment]

DECLARE @sql_cmd NVARCHAR(4000);
DECLARE @db_publication TABLE([db_name] NVARCHAR(128));
DECLARE @db_subscription TABLE([db_name] NVARCHAR(128));
DECLARE @db_name NVARCHAR(128);

DECLARE @subscription TABLE([publisher] NVARCHAR(128)
							,[publisher_db] NVARCHAR(128)
							,[subscriber_db] NVARCHAR(128)
							,[publication] NVARCHAR(128));

INSERT INTO @db_subscription 
	EXEC sp_MSforeachdb N'SELECT ''?'' FROM [?].[INFORMATION_SCHEMA].[TABLES] [T] INNER JOIN [sys].[databases] [D] ON ''?'' = [D].[name] WHERE [TABLE_NAME]=''MSreplication_subscriptions'' AND [D].[is_distributor]=0';

WHILE (SELECT COUNT([db_name]) FROM @db_subscription) > 0
BEGIN
	SET @db_name=(SELECT TOP(1) [db_name] FROM @db_subscription);

	SET @sql_cmd=N'SELECT [publisher], [publisher_db], ''' 
		+ @db_name 
		+ ''' AS [subscriber_db], [publication] FROM [' + @db_name + '].[dbo].[MSreplication_subscriptions]';
		
	INSERT INTO @subscription
		EXEC sp_executesql @stmt = @sql_cmd;

	DELETE FROM @db_subscription WHERE [db_name] = @db_name;
END

SELECT * FROM @subscription;