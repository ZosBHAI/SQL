# Notes (In progress)

## Merge Vs Insert,Update,Delete
1. MERGE statement runs insert, update, or delete operations on a target table from the results of a join with a source table.
2. MERGE statement seems more readable than INSERT+UPDATE(+DELETE)
3. While testing the MERGE logic it better to include the MERGE in a transaction block as mentioned below, so it easy to ROLLBACK incase of unexpected results.Follow below mentioned pattern inorder revert back the changes  does at target.
```
SQL
BEGIN TRANSACTION T1;
MERGE #Test1 t  -- Target 
USING #Test2 s  -- Source 
ON t.ID = s.ID AND t.RowNo = s.RowNo 
  WHEN MATCHED 
    THEN     
      UPDATE SET Value = s.Value 
  WHEN NOT MATCHED 
    THEN       -- Target     
      INSERT (ID, RowNo, Value)     
        VALUES (s.ID, s.RowNo, s.Value);
SELECT 
  *
 FROM #Test1
 ORDER BY ID, RowNo;
ROLLBACK TRANSACTION T1; ---revert the changes done at the target
SELECT *
 FROM #Test1 
 ORDER BY ID, RowNo;

```
4. Merge is slower compared to UPSERT with (INSERT & UPDATE). As a rule of thumb, choose the individual INSERT operations and UPDATE operations, for syncing the large volume of data. Refer :[Merge Vs UPSERT performance](https://michalmolka.medium.com/sql-server-merge-vs-upsert-877702d23674)
5. `WHEN NOT MATCHED BY SOURCE 
    THEN
      DELETE` this will can result in deleting the records from target table that are not in `SOURCE`.To avoid this issue, try to extract the records from `TARGET` table that are there in `SOURCE` for MERGE operation. Refer this article [Hazard of Using the SQL Merge Statement](https://www.sqlservercentral.com/articles/a-hazard-of-using-the-sql-merge-statement)
## Gotchas [OR] Best Parctises 
1. Create Index on the Column referenced  on `CONDITION`. Index needs to be on Target table and the index can be CLUSTERED(where records organized in a sorted fashion) or NON-CLUSTERED.
2. `Separate filtering from matching`. Ensure that the condition only compares columns across the two tables (e.g., target.user_id=source.u_id), not a column with a constant (e.g., source.account_status='ACTIVE'). Having a filter condition on `ON CLAUSE` can return unexpected and incorrect results. 
Ref:[ON <merge_search_condition>](https://learn.microsoft.com/en-us/sql/t-sql/statements/merge-transact-sql?view=sql-server-ver16#on-merge_search_condition)
##### Example:
```SQL
            MERGE target.CreditCardMaster AS T
			USING staged.CreditCardMaster S
			ON T.PAN = S.PAN AND T.ChangeDate = S.ChangeDate
	------		AND T.IsActive = 1 Not a recommended approach 
			WHEN MATCHED AND 
			T.IsActive = 1    --- as per best practises
			AND
			(T.CardPIN <> S.CardPIN OR T.AccountID <> S.AccountID OR T.CardHolderName <> S.CardHolderName OR T.ExpiryDate <> S.ExpiryDate OR T.CreditLimit <> S.CreditLimit)
```


```mermaid
graph TD
    A[Start] --> B[Declare Variables]
    B --> C[Set Full Table Names]
    C --> D[Set Primary Key Conditions]
    D --> E[Parse Primary Keys]
    E --> F[Capture Non-Primary Data Columns]
    F --> G[Build Join Condition]
    G --> H[Build Data Condition]
    H --> I[Deactivate Current Active Records in Target Table]
    I --> J[Insert New Active Records into Target Table]
    J --> K[Update Deleted Records in Target Table]
    K --> L[Print and Execute SQL]
    L --> M[End]

```
