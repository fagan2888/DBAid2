SET NOCOUNT ON;

SELECT 'HADR' AS [heading], 'Mirroring' AS [subheading], 'This is a list of mirrored databases' AS [comment]

SELECT DB_NAME([mirroring].[database_id]) AS [database_name]
	,[mirroring].[mirroring_role_desc] 
	,[mirroring].[mirroring_safety_level_desc]
	,[mirroring].[mirroring_partner_instance]
	,[mirroring].[mirroring_partner_name]
	,[mirroring].[mirroring_witness_name]
FROM [master].[sys].[database_mirroring] [mirroring] 
WHERE [mirroring].[mirroring_guid] IS NOT NULL;