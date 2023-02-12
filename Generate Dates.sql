USE SampleDB
GO

CREATE OR ALTER PROCEDURE usp_GenerateDates
	@StartDate		DATE,
	@EndDate		DATE,
	@FiscalMonth	TINYINT = NULL,
	@FiscalDate		TINYINT = NULL
AS
BEGIN
	SET NOCOUNT ON
	DROP TABLE IF EXISTS #Dates
	DROP TABLE IF EXISTS #Date2
	CREATE TABLE #Dates ( Date DATE )

	WHILE @StartDate <= @EndDate
		BEGIN
			INSERT INTO #Dates VALUES (@StartDate)
			SET @StartDate = DATEADD(DAY,1,@StartDate)
		END
		 
	DECLARE @CurrentDate AS DATE = GETDATE()
	DECLARE @CurrentYear AS INTEGER = YEAR(@CurrentDate)
	DECLARE @CurrentMonth AS INTEGER = MONTH(@CurrentDate)
	DECLARE @CurrentQuarter AS INTEGER = DATEPART(QUARTER, @CurrentDate)
	
	;WITH DateSetup AS(
		SELECT  [Date]
			,[Month Number] = MONTH([Date])
			,[Month] = DATENAME(MONTH, [Date])
			,[Month Short] = LEFT(DATENAME(MONTH,[Date]),3)
			
			,[Quarter Number] = DATENAME(QUARTER, [Date])
			,[Quarter] = 'Q'+DATENAME(QUARTER, [Date])

			,[Year Quarter Number] = YEAR([Date]) * 10 + DATEPART(QUARTER, [Date])
			,[Year Quarter] = 'Q' + CONVERT(VARCHAR,DATEPART(QUARTER, [Date])) + ' ' + CONVERT(VARCHAR,YEAR([Date]))
			,[Year Number] = YEAR([Date])
		FROM #Dates
	)

	,StartAndEndDate AS (
		SELECT *
			,[Month Start Date] = CONVERT(DATE,DATEADD(MONTH,DATEDIFF(MONTH, 0,[Date]),0))
			,[Month End Date] = CONVERT(DATE,DATEADD(MONTH,DATEDIFF(MONTH, 0, [Date])+1,-1))
			,[Quarter Start Date] = CONVERT(DATE, DATEADD(QUARTER,DATEDIFF(QUARTER, 0, [Date]), 0))
			,[Quarter End Date] = CONVERT(DATE, DATEADD(QUARTER,DATEDIFF(QUARTER, 0, [Date]) + 1, -1))
			,[Year Start Date] = DATEFROMPARTS(YEAR([Date]), 1, 1 )
			,[Year End Date] = DATEFROMPARTS(YEAR([Date]), 12, 31)
		FROM DateSetup
	)

	,Offset AS (
		SELECT *
			,[Year Offset Negative] = [Year Number] - @CurrentYear
			,[Year Month Offset Sequential] = ( [Year Number] * 12 ) - 1 + [Month Number]
			,[Quarter Offset Negative] = ( (4 * [Year Number]) + [Quarter Number] ) - ( ( 4 * @CurrentYear ) + @CurrentQuarter )
			,[Year Quarter Offset Sequential] =  ( [Year Number] * 4 ) - 1 + [Quarter Number]
		FROM StartAndEndDate
	)

	,PeriodComplete AS (
		SELECT *
			,[Year Completed] = 
				CASE WHEN [Year End Date] < DATEFROMPARTS(@CurrentYear, 12, 31) 
					THEN 'True' 
					ELSE 'False' 
				END
			,[Month Completed] = 
				CASE WHEN [Month End Date] < CONVERT(DATE,DATEADD(MONTH,DATEDIFF(MONTH, 0, @CurrentDate)+1,-1))
					THEN 'True' 
					ELSE 'False' 
				END
			,[Quarter Completed] = 
				CASE WHEN [Month End Date] < CONVERT(DATE,DATEADD(QUARTER,DATEDIFF(QUARTER, 0, @CurrentDate)+1,-1))
					THEN 'True' 
					ELSE 'False' 
				END
		FROM Offset
	)
	SELECT *
	INTO #Date2
	FROM PeriodComplete

	IF @FiscalMonth IS NULL
		SELECT * 
		FROM #Date2
	ELSE
		BEGIN
			SELECT *
				,[Fiscal Year Number] = [Year Number] + IIF([Month Number] >= 7, 1, 0 )
				,[Fiscal Month Number] = IIF([Month Number]<7,[Month Number]-7+12,[Month Number]-7)+1
				,[Fiscal Month] = [Month]
				,[Fiscal Month Short] = [Month Short]
			FROM #Date2
		END
	DROP TABLE IF EXISTS #Dates
	DROP TABLE IF EXISTS #Date2
	SET NOCOUNT OFF
END
