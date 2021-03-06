﻿/*



*/

CREATE PROCEDURE [checkmk].[check_logshipping]
(
	@writelog BIT = 0
)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @check_output TABLE([state] VARCHAR(8), [message] NVARCHAR(4000));

	DECLARE @primarycount INT;
	DECLARE @secondarycount INT;
	DECLARE @curdate_utc DATETIME;

	SELECT @curdate_utc = GETUTCDATE();

	SELECT @primarycount = COUNT(*)
	FROM [msdb].[dbo].[log_shipping_monitor_primary] [L]
		INNER JOIN [checkmk].[config_database] [C]
				ON [L].[primary_database] = [C].[name] COLLATE DATABASE_DEFAULT
	WHERE [C].[logshipping_check_enabled] = 1;

	SELECT @secondarycount = COUNT(*)
	FROM [msdb].[dbo].[log_shipping_monitor_secondary] [L]
		INNER JOIN [checkmk].[config_database] [C]
				ON [L].[primary_database] = [C].[name] COLLATE DATABASE_DEFAULT
	WHERE [C].[logshipping_check_enabled] = 0;

	INSERT INTO @check_output
		SELECT CASE WHEN DATEDIFF(HOUR, [L].[last_backup_date_utc], @curdate_utc) >= [C].[logshipping_check_hour]  
				THEN [C].[logshipping_check_alert] ELSE 'OK' END AS [state]
			,'database=' 
			+ QUOTENAME([L].[primary_database]) COLLATE DATABASE_DEFAULT 
			+ '; role=PRIMARY; last_backup_minago=' 
			+ CAST(DATEDIFF(MINUTE, [L].[last_backup_date_utc], @curdate_utc) AS NVARCHAR(10)) AS [message]
		FROM [msdb].[dbo].[log_shipping_monitor_primary] [L]
			INNER JOIN [checkmk].[config_database] [C]
					ON [L].[primary_database] = [C].[name] COLLATE DATABASE_DEFAULT
		WHERE [C].[logshipping_check_enabled] = 1
			AND DATEDIFF(MINUTE, [L].[last_backup_date_utc], @curdate_utc) > [L].[backup_threshold]
		UNION ALL
		SELECT CASE WHEN DATEDIFF(HOUR, [L].[last_restored_date_utc], @curdate_utc) >= [C].[logshipping_check_hour] 
				THEN [C].[logshipping_check_alert] ELSE 'OK' END AS [state]
			,'database=' + QUOTENAME([L].[secondary_database]) COLLATE DATABASE_DEFAULT 
			+ '; role=SECONDARY; primary_source=' + QUOTENAME([L].[primary_server]) 
			+ '.' + QUOTENAME([L].[primary_database])
			+ '; last_restore_minago=' + CAST(DATEDIFF(MINUTE, [L].[last_restored_date_utc], @curdate_utc) AS NVARCHAR(10)) AS [message]
		FROM [msdb].[dbo].[log_shipping_monitor_secondary] [L]
			INNER JOIN [checkmk].[config_database] [C]
					ON [L].[secondary_database] = [C].[name] COLLATE DATABASE_DEFAULT
		WHERE [C].[logshipping_check_enabled] = 1
			AND DATEDIFF(MINUTE, [L].[last_restored_date_utc], @curdate_utc) > [L].[restore_threshold]
		ORDER BY [message];

	IF (SELECT COUNT(*) FROM @check_output) < 1 AND (@primarycount > 0 OR @secondarycount > 0)
		INSERT INTO @check_output 
		VALUES('NA', CAST(@primarycount AS NVARCHAR(10)) + ' primary database(s), ' + CAST(@secondarycount AS NVARCHAR(10)) + ' secondary database(s).');
	ELSE IF (SELECT COUNT(*) FROM @check_output) < 1
		INSERT INTO @check_output 
		VALUES('NA', 'Logshipping is currently not configured.');

	SELECT [state], [message] FROM @check_output;

	IF (@writelog = 1)
	BEGIN
		DECLARE @ErrorMsg NVARCHAR(2048);
		DECLARE ErrorCurse CURSOR FAST_FORWARD FOR 
			SELECT [state] + N' - ' + OBJECT_NAME(@@PROCID) + N' - ' + [message] 
			FROM @check_output 
			WHERE [state] NOT IN ('NA','OK');

		OPEN ErrorCurse;
		FETCH NEXT FROM ErrorCurse INTO @ErrorMsg;

		WHILE (@@FETCH_STATUS=0)
		BEGIN
			EXEC xp_logevent 54321, @ErrorMsg, 'WARNING';  
			FETCH NEXT FROM ErrorCurse INTO @ErrorMsg;
		END

		CLOSE ErrorCurse;
		DEALLOCATE ErrorCurse;
	END
END