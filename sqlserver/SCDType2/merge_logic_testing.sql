----staged/source
create schema staged;
CREATE TABLE staged.CreditCardMaster (
    PAN VARCHAR(16) NOT NULL,
    CardPIN CHAR(4) NOT NULL,
    ChangeDate DATE NOT NULL,
    AccountID INT NOT NULL,
    CardHolderName VARCHAR(100),
    ExpiryDate DATE,
    CreditLimit DECIMAL(18, 2),
    row_extract_dttm VARCHAR(20)
 );
Create schema target;
DRop table target.CreditCardMaster;
CREATE TABLE target.CreditCardMaster (
    PAN VARCHAR(16) NOT NULL,
    CardPIN CHAR(4) NOT NULL,
    ChangeDate DATE NOT NULL,
    AccountID INT NOT NULL,
    CardHolderName VARCHAR(100),
    ExpiryDate DATE,
    CreditLimit DECIMAL(18, 2),
    row_extract_dttm VARCHAR(20),
	EffectiveDate DATE,
    ExpirationDate DATE,
    IsActive BIT,
    UpdateDttm datetime
    
);
-----INSERT sample data ---RUN BOOK------

-- Insert sample data into CreditCardMaster
INSERT INTO staged.CreditCardMaster (PAN, CardPIN, ChangeDate, AccountID, CardHolderName, ExpiryDate, CreditLimit,row_extract_dttm)
VALUES
('9234567812345679', '1234', '2024-01-01', 1, 'New John Doe', '2025-12-31', 5000.00,'2024-07-03 13:20:16'),
('9765432187654329', '2345', '2024-03-01', 2, 'New Jane Smith', '2026-11-30', 10000.00,'2024-07-03 13:20:16')

--After running the PROC 
EXEC sp_ImplementSCDType2 @StageSchema = 'staged',@TargetSchema = 'target',@StageTable = 'CreditCardMaster',@TargetTable = 'CreditCardMaster',@PrimaryKeys = 'PAN,ChangeDate'
----Update the existing records 
update staged.CreditCardMaster
set ExpiryDate = '2027-03-01'
where PAN = '9765432187654329';

select * from staged.CreditCardMaster;
---modifying  the primary  key  it should be treated as new record
update staged.CreditCardMaster
set ChangeDate = '2027-03-01'
where PAN = '9234567812345679';


---New records inserted
INSERT INTO staged.CreditCardMaster (PAN, CardPIN, ChangeDate, AccountID, CardHolderName, ExpiryDate, CreditLimit,row_extract_dttm)
VALUES
('1234567812345679', '1234', '2024-01-01', 1, 'Bob', '2025-12-31', 5000.00,'2024-07-03 13:20:16'),
('1235432187654329', '2345', '2024-03-01', 2, 'Jack', '2026-11-30', 10000.00,'2024-07-03 13:20:16')


EXEC sp_ImplementSCDType2 @StageSchema = 'staged',@TargetSchema = 'target',@StageTable = 'CreditCardMaster',@TargetTable = 'CreditCardMaster',@PrimaryKeys = 'PAN,ChangeDate'
------------OR --------------
EXEC sp_MergeImplementationSCDType2 @StageSchema = 'staged',@TargetSchema = 'target',@StageTable = 'CreditCardMaster',@TargetTable = 'CreditCardMaster',@PrimaryKeys = 'PAN,ChangeDate'

-- Verify the data
select * from target.CreditCardMaster;
select * from staged.CreditCardMaster;
---deleting the record from staged table
delete from staged.CreditCardMaster where PAN = '9234567812345679';
EXEC sp_ImplementSCDType2 @StageSchema = 'staged',@TargetSchema = 'target',@StageTable = 'CreditCardMaster',@TargetTable = 'CreditCardMaster',@PrimaryKeys = 'PAN,ChangeDate'


--------------------======o R ========---------
EXEC sp_MergeImplementationSCDType2 @StageSchema = 'staged',@TargetSchema = 'target',@StageTable = 'CreditCardMaster',@TargetTable = 'CreditCardMaster',@PrimaryKeys = 'PAN,ChangeDate'

---For merge logic
EXEC sp_MergeImplementationSCDType2 @StageSchema = 'staged',@TargetSchema = 'target',@StageTable = 'CreditCardMaster',@TargetTable = 'CreditCardMaster',@PrimaryKeys = 'PAN,ChangeDate'
-----------------------==================TEST RUN STEP E N D ======================------------------------------------
----- SCD type 2 logic implementation ----
--1) Exclude metadata columns in 
--2)  Primary Key columns

DECLARE @StageTable NVARCHAR(128);
DECLARE @StageSchema NVARCHAR(128);
DECLARE @TargetTable NVARCHAR(128);
DECLARE @TargetSchema NVARCHAR(128);
DECLARE @FullStageTableName NVARCHAR(128);
DECLARE @FullTargetTableName NVARCHAR(128);
DECLARE @EffectiveDateColumn NVARCHAR(128);
DECLARE @EndDateColumn NVARCHAR(128);
DECLARE @IsActiveColumn NVARCHAR(128) ;
DECLARE @InsertDttmColumn NVARCHAR(128) ;
DECLARE @UpdateDttmColumn NVARCHAR(128) ;
DECLARE @sql NVARCHAR(MAX);
DECLARE @columns NVARCHAR(MAX);
DECLARE @joinCondition NVARCHAR(MAX);
DECLARE @targetKeysNullCondition NVARCHAR(MAX);
DECLARE @stageKeysNullCondition NVARCHAR(MAX);
DECLARE @PrimaryKeys NVARCHAR(MAX);
DECLARE @InClause NVARCHAR(MAX)


SET @StageSchema = 'staged';
SET @TargetSchema = 'target';
SET @StageTable = 'CreditCardMaster';
SET @TargetTable = 'CreditCardMaster';
SET @FullStageTableName = @StageSchema+'.'+ @StageTable;
SET @FullTargetTableName = @TargetSchema+'.'+@TargetTable;
SET @IsActiveColumn = 'IsActive';
SET @EndDateColumn   = 'EndDate';
SET @EffectiveDateColumn = 'EffectiveDate';
SET @InsertDttmColumn = 'InsertDttm';
SET @UpdateDttmColumn = 'UpdateDttm';
SET @EffectiveDateColumn = 'EffectiveDate';


SET @PrimaryKeys = 'PAN'


----Logic to seperate the primary key and build the IN clause condition
DECLARE @PrimaryColumnNamesValueTable TABLE (ColumnNames NVARCHAR(128))
DECLARE @NonPrimaryDataColumnsTable TABLE (ColumnNames NVARCHAR(128))
-- Parse the comma-delimited values string
INSERT INTO @PrimaryColumnNamesValueTable (ColumnNames)
SELECT TRIM(value)
FROM STRING_SPLIT(@PrimaryKeys, ',')

---- Capturing the Only Data Columns 
INSERT INTO @NonPrimaryDataColumnsTable(ColumnNames)
select column_name 
FROM INFORMATION_SCHEMA.COLUMNS
WHERE table_schema = @StageSchema and table_name = @StageTable AND column_name
NOT IN (@EffectiveDateColumn, @EndDateColumn, @IsActiveColumn,@InsertDttmColumn,@UpdateDttmColumn,'row_extract_dttm')
AND column_name  NOT IN (select ColumnNames from @PrimaryColumnNamesValueTable);


SELECT @columns = STRING_AGG(QUOTENAME(ColumnNames), ', ')
FROM @NonPrimaryDataColumnsTable;

----Building  the JOIN condition dynamically 
SET @JoinCondition = ''
SELECT @JoinCondition = @JoinCondition + 
    CASE 
        WHEN LEN(@JoinCondition) = 0 THEN ''
        ELSE ' AND '
    END + 'T.' + ColumnNames + ' = S.' + ColumnNames
FROM @PrimaryColumnNamesValueTable

-----Building  NULL check  for target table -------
SET @targetKeysNullCondition = ''
SELECT @targetKeysNullCondition = @targetKeysNullCondition + 
    CASE 
        WHEN LEN(@targetKeysNullCondition) = 0 THEN ''
        ELSE ' OR '
    END + 'T.' + ColumnNames + ' IS NULL'
FROM @PrimaryColumnNamesValueTable
-----Building  NULL check  for stage table -------
SET @stageKeysNullCondition = ''
SELECT @stageKeysNullCondition = @stageKeysNullCondition + 
    CASE 
        WHEN LEN(@stageKeysNullCondition) = 0 THEN ''
        ELSE ' OR '
    END + 'S.' + ColumnNames + ' IS NULL'
FROM @PrimaryColumnNamesValueTable

SET @sql = '
    UPDATE ' + @FullTargetTableName + '
        SET T.' + @EndDateColumn + ' = GETDATE(),
        T.' +  @UpdateDttmColumn + ' = GETDATE(),
        T.' + @IsActiveColumn + ' = 0
    FROM ' + @FullTargetTableName + ' T
    JOIN ' + @FullStageTableName + ' S
    ON ' + @joinCondition + '
    WHERE T.' + @IsActiveColumn + ' = 1
    AND ('
SELECT @sql = @sql + 'T.' + QUOTENAME(ColumnNames) + ' <> S.' + QUOTENAME(ColumnNames) + ' OR '
FROM @NonPrimaryDataColumnsTable

SET @sql = LEFT(@sql, LEN(@sql) - 3) + ')';
        
---Adding insert logic 
 SELECT @columns = STRING_AGG(QUOTENAME(column_name), ', ')
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE table_schema = @StageSchema and table_name = @StageTable 

SET @sql = @sql + '
    INSERT INTO ' + @FullTargetTableName + ' (' + @columns + ', ' + @EffectiveDateColumn + ', ' + @EndDateColumn + ', ' + @IsActiveColumn + ', '  +  @UpdateDttmColumn + ')
    SELECT ' + @columns + ', GETDATE(), NULL, 1 , GETDATE()
    FROM ' + @FullStageTableName + ' S
    LEFT JOIN ' + @FullTargetTableName + ' T
    ON ' + @joinCondition + '
    WHERE ' + @targetKeysNullCondition+ ' OR (T.' + @IsActiveColumn + ' = 1 AND ('

SELECT @sql = @sql + 'T.' + QUOTENAME(ColumnNames) + ' <> S.' + QUOTENAME(ColumnNames) + ' OR '
FROM @NonPrimaryDataColumnsTable;   

SET @sql = LEFT(@sql, LEN(@sql) - 3) + '))';
---PRINT @sql;
---- Capture deleted records from the source 
SET @sql = @sql + '
    UPDATE ' + @FullTargetTableName + '
        SET T.' + @EndDateColumn + ' = GETDATE(),
        SET T.' + @UpdateDttmColumn + ' = GETDATE(),
        T.' + @IsActiveColumn + ' = 0
    FROM ' + @FullStageTableName + ' S
    LEFT JOIN ' + @FullTargetTableName + ' T
    ON ' + @joinCondition + '
    WHERE ' + @stageKeysNullCondition

PRINT @sql;
EXEC sp_executesql @sql;




create SCHEMA staged;

DRop table target.CreditCardMaster;
CREATE TABLE target.CreditCardMaster (
    PAN VARCHAR(16) NOT NULL,
    CardPIN CHAR(4) NOT NULL,
    ChangeDate DATE NOT NULL,
    AccountID INT NOT NULL,
    CardHolderName VARCHAR(100),
    ExpiryDate DATE,
    CreditLimit DECIMAL(18, 2),
    row_extract_dttm VARCHAR(20),
	EffectiveDate DATE,
    ExpirationDate DATE,
    IsActive BIT,
    UpdateDttm datetime
    
);
select * from staged.CreditCardMaster
select * from target.CreditCardMaster
delete from target.CreditCardMaster

delete from staged.CreditCardMaster where ChangeDate in ('2024-02-01','2024-04-01')
update staged.CreditCardMaster
set ChangeDate = '2024-03-01',
CardHolderName = 'Twice Jane Smith',
ExpiryDate = '2029-03-01'
where PAN  = '8765432187654321';

-------------------------------------------------------------------
---------------------Final Version without Merge -------------------
---------------------------------------------------------------------
DECLARE @StageTable NVARCHAR(128);
DECLARE @StageSchema NVARCHAR(128);
DECLARE @TargetTable NVARCHAR(128);
DECLARE @TargetSchema NVARCHAR(128);
DECLARE @FullStageTableName NVARCHAR(128);
DECLARE @FullTargetTableName NVARCHAR(128);
DECLARE @EffectiveDateColumn NVARCHAR(128);
DECLARE @EndDateColumn NVARCHAR(128);
DECLARE @IsActiveColumn NVARCHAR(128) ;
DECLARE @UpdateDttmColumn NVARCHAR(128) ;
DECLARE @sql NVARCHAR(MAX);
DECLARE @columns NVARCHAR(MAX);
DECLARE @joinCondition NVARCHAR(MAX);
DECLARE @targetKeysNullCondition NVARCHAR(MAX);
DECLARE @stageKeysNullCondition NVARCHAR(MAX);
DECLARE @PrimaryKeys NVARCHAR(MAX);
DECLARE @FirstPrimaryKey VARCHAR(100);
DECLARE @PrimaryColumnNamesValueTable TABLE (ColumnNames NVARCHAR(128))
DECLARE @NonPrimaryDataColumnsTable TABLE (ColumnNames NVARCHAR(128))

SET @StageSchema = 'staged';
SET @TargetSchema = 'target';
SET @StageTable = 'CreditCardMaster';
SET @TargetTable = 'CreditCardMaster';
SET @FullStageTableName = @StageSchema+'.'+ @StageTable;
SET @FullTargetTableName = @TargetSchema+'.'+@TargetTable;
SET @IsActiveColumn = 'IsActive';
SET @EndDateColumn   = 'ExpirationDate';
SET @EffectiveDateColumn = 'EffectiveDate';
SET @UpdateDttmColumn = 'UpdateDttm';
SET @EffectiveDateColumn = 'EffectiveDate';
SET @PrimaryKeys = 'PAN,ChangeDate'
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

-------Deactivate  current active records from target table  to inactive 

SET @sql = '
    UPDATE ' + @FullTargetTableName + '
        SET ' + @EndDateColumn + ' = GETDATE(),
        ' +  @UpdateDttmColumn + ' = GETDATE(),
        ' + @IsActiveColumn + ' = 0
    FROM ' + @FullTargetTableName + ' T
    JOIN ' + @FullStageTableName + ' S
    ON ' + @joinCondition + '
    WHERE T.' + @IsActiveColumn + ' = 1
    AND ('
SELECT @sql = @sql + 'T.' + QUOTENAME(ColumnNames) + ' <> S.' + QUOTENAME(ColumnNames) + ' OR '
FROM @NonPrimaryDataColumnsTable

SET @sql = LEFT(@sql, LEN(@sql) - 3) + ');'; ---semi colon should be there  after closing paranthesis,as it is followed by a CTE
   
---Adding insert logic 
 SELECT @columns = STRING_AGG('S.'+QUOTENAME(column_name), ', ')
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE table_schema = @StageSchema and table_name = @StageTable 
SET @sql = @sql + ' 
    With ActiveRecords as (
	SELECT  * FROM  '+ @FullTargetTableName + ' T
	WHERE T.IsActive = 1
)
    INSERT INTO ' + @FullTargetTableName + ' (' + @columns + ', ' + @EffectiveDateColumn + ', ' + @EndDateColumn + ', ' + @IsActiveColumn + ', '  +  @UpdateDttmColumn + ')
    SELECT ' + @columns + ', GETDATE(), NULL, 1 , GETDATE()
    FROM ' + @FullStageTableName + ' S
    LEFT JOIN ActiveRecords T
    ON ' + @joinCondition + '
    WHERE (' + @targetKeysNullCondition+ ') '
---- Capture deleted records from the source 
SET @sql = @sql + '
    UPDATE ' + @FullTargetTableName + '
        SET ' + @EndDateColumn + ' = GETDATE(),
         ' + @UpdateDttmColumn + ' = GETDATE(),
        ' + @IsActiveColumn + ' = 0
    FROM ' + @FullTargetTableName + ' T
    LEFT JOIN ' + @FullStageTableName + ' S
    ON ' + @joinCondition + '
    WHERE ' + @stageKeysNullCondition + ' AND (T.' + @IsActiveColumn + ' = 1)'
    

PRINT @sql;
 EXEC sp_executesql @sql;







-----------------------------------------------------------------------
------------------------------E  n   D -------------------------------
-----------------------------------------------------------------------

--------------------------Stored PRODECURE without Merge ----------------------
DROp PROCEDURE sp_ImplementSCDType2;
CREATE PROCEDURE sp_ImplementSCDType2
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
	DECLARE @joinCondition NVARCHAR(MAX);
	DECLARE @targetKeysNullCondition NVARCHAR(MAX);
	DECLARE @stageKeysNullCondition NVARCHAR(MAX);
	DECLARE @FirstPrimaryKey VARCHAR(100);
	DECLARE @PrimaryColumnNamesValueTable TABLE (ColumnNames NVARCHAR(128));
	DECLARE @NonPrimaryDataColumnsTable TABLE (ColumnNames NVARCHAR(128));
	DECLARE @DataCondition NVARCHAR(MAX);


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

	-------Deactivate  current active records from target table  to inactive 

	SET @sql = '
		UPDATE ' + @FullTargetTableName + '
			SET ' + @EndDateColumn + ' = GETDATE(),
			' +  @UpdateDttmColumn + ' = GETDATE(),
			' + @IsActiveColumn + ' = 0
		FROM ' + @FullTargetTableName + ' T
		JOIN ' + @FullStageTableName + ' S
		ON ' + @joinCondition + '
		WHERE T.' + @IsActiveColumn + ' = 1
		AND ('+ @DataCondition + ');' 


	--SET @sql = LEFT(@sql, LEN(@sql) - 3) + ');'; ---semi colon should be there  after closing paranthesis,as it is followed by a CTE
	
	---Adding insert logic 
	SELECT @columns = STRING_AGG('S.'+QUOTENAME(column_name), ', ')
		FROM INFORMATION_SCHEMA.COLUMNS
		WHERE table_schema = @StageSchema and table_name = @StageTable 
	SET @sql = @sql + ' 
		With ActiveRecords as (
		SELECT  * FROM  '+ @FullTargetTableName + ' T
		WHERE T.IsActive = 1
	)
		INSERT INTO ' + @FullTargetTableName + ' (' + @columns + ', ' + @EffectiveDateColumn + ', ' + @EndDateColumn + ', ' + @IsActiveColumn + ', '  +  @UpdateDttmColumn + ')
		SELECT ' + @columns + ', GETDATE(), NULL, 1 , GETDATE()
		FROM ' + @FullStageTableName + ' S
		LEFT JOIN ActiveRecords T
		ON ' + @joinCondition + '
		WHERE (' + @targetKeysNullCondition+ ') '
	---- Capture deleted records from the source 
	SET @sql = @sql + '
		UPDATE ' + @FullTargetTableName + '
			SET ' + @EndDateColumn + ' = GETDATE(),
			' + @UpdateDttmColumn + ' = GETDATE(),
			' + @IsActiveColumn + ' = 0
		FROM ' + @FullTargetTableName + ' T
		LEFT JOIN ' + @FullStageTableName + ' S
		ON ' + @joinCondition + '
		WHERE ' + @stageKeysNullCondition + ' AND (T.' + @IsActiveColumn + ' = 1)'
		

	PRINT @sql;
	EXEC sp_executesql @sql;
END;
GO

	EXEC sp_ImplementSCDType2 @StageSchema = 'staged',@TargetSchema = 'target',@StageTable = 'CreditCardMaster',@TargetTable = 'CreditCardMaster',@PrimaryKeys = 'PAN,ChangeDate'

-------------------------- E  N  D ----------------------------------------

------Testing  MERGE Logic -----------------------------------------------
DECLARE @StageTable NVARCHAR(128);
DECLARE @StageSchema NVARCHAR(128);
DECLARE @TargetTable NVARCHAR(128);
DECLARE @TargetSchema NVARCHAR(128);
DECLARE @FullStageTableName NVARCHAR(128);
DECLARE @FullTargetTableName NVARCHAR(128);
DECLARE @EffectiveDateColumn NVARCHAR(128);
DECLARE @EndDateColumn NVARCHAR(128);
DECLARE @IsActiveColumn NVARCHAR(128) ;
DECLARE @UpdateDttmColumn NVARCHAR(128) ;
DECLARE @sql NVARCHAR(MAX);
DECLARE @stageColumns NVARCHAR(MAX);
DECLARE @columns NVARCHAR(MAX);
DECLARE @JoinCondition NVARCHAR(MAX);
DECLARE @DataCondition NVARCHAR(MAX);

DECLARE @targetKeysNullCondition NVARCHAR(MAX);
DECLARE @stageKeysNullCondition NVARCHAR(MAX);
DECLARE @PrimaryKeys NVARCHAR(MAX);
DECLARE @InClause NVARCHAR(MAX);
DECLARE @FirstPrimaryKey VARCHAR(100);


SET @StageSchema = 'staged';
SET @TargetSchema = 'target';
SET @StageTable = 'CreditCardMaster';
SET @TargetTable = 'CreditCardMaster';
SET @FullStageTableName = @StageSchema+'.'+ @StageTable;
SET @FullTargetTableName = @TargetSchema+'.'+@TargetTable;
SET @IsActiveColumn = 'IsActive';
SET @EndDateColumn   = 'ExpirationDate';
SET @EffectiveDateColumn = 'EffectiveDate';
SET @UpdateDttmColumn = 'UpdateDttm';
SET @EffectiveDateColumn = 'EffectiveDate';


SET @PrimaryKeys = 'PAN,ChangeDate'
SET @FirstPrimaryKey = LEFT(@PrimaryKeys,CHARINDEX(',',@PrimaryKeys+',')-1);


----Logic to seperate the primary key and build the IN clause condition
DECLARE @PrimaryColumnNamesValueTable TABLE (ColumnNames NVARCHAR(128))
DECLARE @NonPrimaryDataColumnsTable TABLE (ColumnNames NVARCHAR(128))
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
        AND T.' + @IsActiveColumn + ' = 1
        WHEN MATCHED AND 
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
---EXEC sp_executesql @sql;



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


----SQL that is generated for the table 
INSERT INTO target.CreditCardMaster ([PAN], [CardPIN], [ChangeDate], [AccountID], [CardHolderName], [ExpiryDate], [CreditLimit], [row_extract_dttm], EffectiveDate, ExpirationDate, IsActive, UpdateDttm)
		SELECT [PAN], [CardPIN], [ChangeDate], [AccountID], [CardHolderName], [ExpiryDate], [CreditLimit], [row_extract_dttm], GETDATE(), NULL, 1 , GETDATE()
		FROM  ( 
			MERGE target.CreditCardMaster AS T
			USING staged.CreditCardMaster S
			ON T.PAN = S.PAN AND T.ChangeDate = S.ChangeDate
	------		AND T.IsActive = 1 INefficent way
			WHEN MATCHED AND 
			T.IsActive = 1
			AND
			(T.CardPIN <> S.CardPIN OR T.AccountID <> S.AccountID OR T.CardHolderName <> S.CardHolderName OR T.ExpiryDate <> S.ExpiryDate OR T.CreditLimit <> S.CreditLimit)
	 THEN  UPDATE 
			SET ExpirationDate = GETDATE(),
			 UpdateDttm = GETDATE(),
			IsActive = 0
	WHEN NOT MATCHED BY TARGET
	   THEN INSERT ( 
		   [PAN], [CardPIN], [ChangeDate], [AccountID], [CardHolderName], [ExpiryDate], [CreditLimit], [row_extract_dttm], EffectiveDate, ExpirationDate, IsActive, UpdateDttm)
		   VALUES( S.[PAN], S.[CardPIN], S.[ChangeDate], S.[AccountID], S.[CardHolderName], S.[ExpiryDate], S.[CreditLimit], S.[row_extract_dttm], GETDATE(), NULL, 1 , GETDATE()
		   )
	WHEN NOT MATCHED BY SOURCE AND  T.IsActive = 1
	   THEN UPDATE 
		SET
		ExpirationDate = GETDATE(),
			 UpdateDttm = GETDATE(),
			IsActive = 0
			OUTPUT $action AS Action
					,[S].*
					) AS MergeOutput
		WHERE MergeOutput.Action = 'UPDATE' 
		AND PAN IS NOT NULL;

