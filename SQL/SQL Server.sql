USE [ContosoRetailDW] -- Change with your Database
GO


ALTER   PROCEDURE [dbo].[usp_GenerateDateTable]
	@StartDate		DATE,
	@EndDate		DATE,
	@FiscalMonth		TINYINT = NULL,
	@FiscalDate		TINYINT = NULL
AS
BEGIN
	SET NOCOUNT ON
	DROP TABLE IF EXISTS #____Dates
	DROP TABLE IF EXISTS #____Date2
	CREATE TABLE #____Dates ( Date DATE )

	WHILE @StartDate <= @EndDate
		BEGIN
			INSERT INTO #____Dates VALUES (@StartDate)
			SET @StartDate = DATEADD(DAY,1,@StartDate)
		END
		 
	DECLARE @CurrentDate AS DATE = GETDATE()
	DECLARE @CurrentYear AS INTEGER = YEAR(@CurrentDate)
	DECLARE @CurrentMonth AS INTEGER = MONTH(@CurrentDate)
	DECLARE @CurrentQuarter AS INTEGER = DATEPART(QUARTER, @CurrentDate)
	
	;WITH YearMonthDay AS(
		SELECT  [Date]
			,[Month Number] = MONTH([Date])
			,[Quarter Number] = DATENAME(QUARTER, [Date])
			,[Year Number] = YEAR([Date])
		FROM #____Dates
	)

	,DayColumns AS (
		SELECT *
			,[Day of Week Number] = DATEPART(DAY, [Date])
			,[Day of Week Name] = DATENAME(WEEKDAY, [Date])
			,[Day of Week Intial] = LEFT(DATENAME(WEEKDAY, [Date]), 3)
			,[Day of Year] = DATEPART(DAYOFYEAR, [Date])
			,[Current Day Offset] = CONVERT(INT,CONVERT(DATETIME,[Date])) - CONVERT(INT,CONVERT(DATETIME, @CurrentDate))
			,[Is After Today] = IIF([Date] <= @CurrentDate, 'False', 'True')
			,[Is Working Day] = IIF(DATEPART(WEEKDAY, [Date]) IN (2, 3, 4, 5, 6), 'True', 'False')
			,[Day Type] = IIF(DATEPART(WEEKDAY, [Date]) IN (2, 3, 4, 5, 6), 'Working', 'Weekend')
		FROM YearMonthDay
	)

	,MonthColumns AS (
		SELECT *
			,[Month] = DATENAME(MONTH, [Date])
			,[Month Short] = LEFT(DATENAME(MONTH,[Date]),3)
			,[Month Stort Date] = CONVERT(DATE,DATEADD(MONTH,DATEDIFF(MONTH, 0,[Date]),0))
			,[Month End Date] = CONVERT(DATE,DATEADD(MONTH,DATEDIFF(MONTH, 0, [Date])+1,-1))

			-- Can be Subquery instead but costs readability
			,[Month Completed] = 
				CASE 
					WHEN CONVERT(DATE,DATEADD(MONTH,DATEDIFF(MONTH, 0, [Date])+1,-1)) -- Start Date
							< CONVERT(DATE,DATEADD(MONTH,DATEDIFF(MONTH, 0, @CurrentDate)+1,-1)) -- End Date
					THEN 'True' 
					ELSE 'False' 
				END
		FROM DayColumns
	)

	,QuarterColumns AS (
		SELECT * 
			,[Quarter Start Date] = CONVERT(DATE, DATEADD(QUARTER,DATEDIFF(QUARTER, 0, [Date]), 0))
			,[Quarter End Date] = CONVERT(DATE, DATEADD(QUARTER,DATEDIFF(QUARTER, 0, [Date]) + 1, -1))
			,[Quarter] = 'Q'+DATENAME(QUARTER, [Date])
			,[Quarter Offset Negative] = ( (4 * [Year Number]) + [Quarter Number] ) - ( ( 4 * @CurrentYear ) + @CurrentQuarter )
			,[Quarter Completed] = 
				CASE 
					WHEN CONVERT(DATE, DATEADD(QUARTER,DATEDIFF(QUARTER, 0, [Date]) + 1, -1)) 
							< CONVERT(DATE,DATEADD(QUARTER,DATEDIFF(QUARTER, 0, @CurrentDate)+1,-1))
					THEN 'True' 
					ELSE 'False' 
				END
		FROM MonthColumns
	)

	,YearColumns AS (
		SELECT *
			,[Year Start Date] = DATEFROMPARTS(YEAR([Date]), 1, 1 )
			,[Year End Date] = DATEFROMPARTS(YEAR([Date]), 12, 31)
			,[Year Offset Negative] = [Year Number] - @CurrentYear
			,[Year Month Offset Sequential] = ( [Year Number] * 12 ) - 1 + [Month Number]
			,[Year Quarter Offset Sequential] =  ( [Year Number] * 4 ) - 1 + [Quarter Number]
			,[Year Quarter Number] = YEAR([Date]) * 10 + DATEPART(QUARTER, [Date])
			,[Year Quarter] = 'Q' + CONVERT(VARCHAR,DATEPART(QUARTER, [Date])) + ' ' + CONVERT(VARCHAR,YEAR([Date]))
			,[Year Completed] = 
				CASE 
					WHEN DATEFROMPARTS(YEAR([Date]), 12, 31) 
							< DATEFROMPARTS(@CurrentYear, 12, 31) 
					THEN 'True' 
					ELSE 'False' 
				END
		FROM QuarterColumns
	)


	SELECT *
	INTO #____Date2
	FROM YearColumns

	IF @FiscalMonth IS NULL
		SELECT * 
		FROM #____Date2
	ELSE
		BEGIN
			SELECT *
				,[Fiscal Year Number] = [Year Number] + IIF([Month Number] >= @FiscalMonth, 1, 0 )
				,[Fiscal Month Number] = IIF([Month Number]<@FiscalMonth,[Month Number]-@FiscalMonth+12,[Month Number]-@FiscalMonth)+1
				,[Fiscal Month] = [Month]
				,[Fiscal Month Short] = [Month Short]
				,[Fiscal Day Number in Year] = 
					CONVERT(INT,CONVERT(DATETIME,[Date]) - 
						DATEFROMPARTS([Year Number] + IIF([Month Number]<@FiscalMonth,1,0) * -1, @FiscalMonth, 1)+1)
				,[Fiscal Year Month Number] = 
					([Year Number] + IIF([Month Number] >= @FiscalMonth, 1, 0 )) * 100 
						+ IIF([Month Number]<@FiscalMonth,[Month Number]-@FiscalMonth+12,[Month Number]-@FiscalMonth)+1
				,[Fiscal Year Month] = CONVERT(VARCHAR,[Year Number] + IIF([Month Number] >= @FiscalMonth, 1, 0 )) + ' ' + [Month Short]
			FROM #____Date2
		END

	DROP TABLE IF EXISTS #____Dates
	DROP TABLE IF EXISTS #____Date2
	SET NOCOUNT OFF
END
