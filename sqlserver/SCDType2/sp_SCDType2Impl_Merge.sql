------------------------------------ Stored PROCEDURE --- MERGE LOGIC -------------------------------------------------------

DROp PROCEDURE sp_MergeImplementationSCDType2;
CREATE PROCEDURE sp_MergeImplementationSCDType2
    @StageTable NVARCHAR(128),
	@StageSchema NVARCHAR(128),
    @TargetTable NVARCHAR(128),
	@TargetSchema NVARCHAR(128),
	@PrimaryKeys NVARCHAR(MAX),
    @EffectiveDateColumn NVARCHAR(128) = 'EffectiveDate',
    @EndDateColumn NVARCHAR(128) = 'ExpirationDate',
    @IsActiveColumn NVARCHAR(128) = 'IsActive',
	@UpdateDttmColumn NVARCHAR(128) = 'UpdateDttm'
AS
BEGIN
SET NOCOUNT OFF;
	DECLARE @FullStageTableName NVARCHAR(128);
	DECLARE @FullTargetTableName NVARCHAR(128);
	DECLARE @sql NVARCHAR(MAX);
	DECLARE @columns NVARCHAR(MAX);
	DECLARE @JoinCondition NVARCHAR(MAX);
	DECLARE @DataCondition NVARCHAR(MAX);
	DECLARE @targetKeysNullCondition NVARCHAR(MAX);
	DECLARE @stageKeysNullCondition NVARCHAR(MAX);
	DECLARE @FirstPrimaryKey VARCHAR(100);
	DECLARE @PrimaryColumnNamesValueTable TABLE (ColumnNames NVARCHAR(128));
	DECLARE @NonPrimaryDataColumnsTable TABLE (ColumnNames NVARCHAR(128));
	DECLARE @stageColumns NVARCHAR(MAX);


	SET @FullStageTableName = @StageSchema+'.'+ @StageTable;
	SET @FullTargetTableName = @TargetSchema+'.'+@TargetTable;

	SET @FirstPrimaryKey = LEFT(@PrimaryKeys,CHARINDEX(',',@PrimaryKeys+',')-1);
	---- Set the filter condition
	SET @stageKeysNullCondition = 'S.' + @FirstPrimaryKey + ' IS NULL';
	SET @targetKeysNullCondition = 'T.' + @FirstPrimaryKey + ' IS NULL';

	----Logic to seperate the primary key and build the IN clause condition
	-- Parse the comma-delimited values string
	INSERT INTO @PrimaryColumnNamesValueTable (ColumnNames)
	SELECT TRIM(value)
	FROM STRING_SPLIT(@PrimaryKeys, ',')

	---- Capturing the Only Data Columns 
	INSERT INTO @NonPrimaryDataColumnsTable(ColumnNames)
	select column_name 
	FROM INFORMATION_SCHEMA.COLUMNS
	WHERE table_schema = @StageSchema and table_name = @StageTable AND column_name
	NOT IN (@EffectiveDateColumn, @EndDateColumn, @IsActiveColumn,@UpdateDttmColumn,'row_extract_dttm')
	AND column_name  NOT IN (select ColumnNames from @PrimaryColumnNamesValueTable);

	----Building  the JOIN condition dynamically 
	SET @JoinCondition = ''
	SELECT @JoinCondition = @JoinCondition + 
		CASE 
			WHEN LEN(@JoinCondition) = 0 THEN ''
			ELSE ' AND '
		END + 'T.' + ColumnNames + ' = S.' + ColumnNames
	FROM @PrimaryColumnNamesValueTable
	
	--- Build the  condition to validate the non data column
	SET @DataCondition = ''
	SELECT @DataCondition = @DataCondition + 
		CASE 
			WHEN LEN(@DataCondition) = 0 THEN ''
			ELSE ' OR '
		END + 'T.' + ColumnNames + ' <> S.' + ColumnNames
	FROM @NonPrimaryDataColumnsTable
			
	---Adding Merge logic  
	 SELECT @stageColumns = STRING_AGG('S.'+QUOTENAME(column_name), ', ')
		FROM INFORMATION_SCHEMA.COLUMNS
		WHERE table_schema = @StageSchema and table_name = @StageTable 
	SELECT @columns = STRING_AGG(QUOTENAME(column_name), ', ')
		FROM INFORMATION_SCHEMA.COLUMNS
		WHERE table_schema = @StageSchema and table_name = @StageTable 

	SET @sql =  '
		INSERT INTO ' + @FullTargetTableName + ' (' + @columns + ', ' + @EffectiveDateColumn + ', ' + @EndDateColumn + ', ' + @IsActiveColumn + ', '  +  @UpdateDttmColumn + ')
		SELECT ' + @columns + ', GETDATE(), NULL, 1 , GETDATE()
		FROM  ( 
			MERGE '  + @FullTargetTableName + ' AS T
			USING ' + @FullStageTableName + ' S
			ON ' + @joinCondition + '
			
			WHEN MATCHED AND 
			AND T.' + @IsActiveColumn + ' = 1
			(' + @DataCondition + ')' 

	SET @sql = @sql + '
	 THEN  UPDATE 
			SET ' + @EndDateColumn + ' = GETDATE(),
			 ' + @UpdateDttmColumn + ' = GETDATE(),
			' + @IsActiveColumn + ' = 0
	WHEN NOT MATCHED BY TARGET
	   THEN INSERT ( 
		   ' + @columns  + ', ' + @EffectiveDateColumn + ', ' + @EndDateColumn + ', ' + @IsActiveColumn + ', '  +  @UpdateDttmColumn + ')
		   VALUES( ' + @stageColumns + ', GETDATE(), NULL, 1 , GETDATE()
		   )
	WHEN NOT MATCHED BY SOURCE AND  ' + 'T.' + @IsActiveColumn + ' = 1
	   THEN UPDATE 
		SET
		' + @EndDateColumn + ' = GETDATE(),
			 ' + @UpdateDttmColumn + ' = GETDATE(),
			' + @IsActiveColumn + ' = 0
			OUTPUT $action AS Action
					,[S].*
					) AS MergeOutput
		WHERE MergeOutput.Action = ''UPDATE'' 
		AND ' + @FirstPrimaryKey + ' IS NOT NULL;'
	  

	PRINT @sql;
	EXEC sp_executesql @sql;

END;
GO

EXEC sp_MergeImplementationSCDType2 @StageSchema = 'staged',@TargetSchema = 'target',@StageTable = 'CreditCardMaster',@TargetTable = 'CreditCardMaster',@PrimaryKeys = 'PAN,ChangeDate'

