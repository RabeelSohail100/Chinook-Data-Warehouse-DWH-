									# Step 1: Setup OLAP Schema
DELIMITER //

Drop Procedure If Exists chinook_oltp.DataWarehouse_Setup //
Create Procedure chinook_oltp.DataWarehouse_Setup()
Begin
    Drop Database If Exists Chinook_OLAP;
    Create Database Chinook_OLAP;
End //

DELIMITER ;

CALL chinook_oltp.DataWarehouse_Setup();

										#Step 2: Creating Dimensions
DELIMITER //

Drop Procedure If Exists Create_Customer_Dim //
Create Procedure Create_Customer_Dim()
Begin
    Drop Table If Exists chinook_olap.Customer_Dim;
    Create Table chinook_olap.Customer_Dim AS
    Select 
        CustomerId, FirstName, LastName, Address, PostalCode, Phone, Fax, Email
    From chinook_oltp.Customer;

    Alter Table chinook_olap.Customer_Dim 
    Add Primary Key (CustomerId),
    Add Column Created_at DateTime Default Current_Timestamp,
    Add Column Updated_at DateTime Default Current_Timestamp On Update Current_Timestamp;
End //

DELIMITER ;

CALL Create_Customer_Dim();

DELIMITER //

Drop Procedure If Exists Create_Track_Dim //
Create Procedure Create_Track_Dim()
Begin
	Drop Table If Exists chinook_olap.Track_Dim;
    Create Table chinook_olap.Track_Dim As
    Select
		t.TrackId, t.Name As TrackName, t.Composer, t.Milliseconds, t.Bytes, t.UnitPrice, 
        ar.ArtistId, ar.Name As ArtistName,
        a.AlbumId, a.Title As AlbumTitle,
        g.GenreId, g.Name As GenreName
	From chinook_oltp.track t
    Left Join chinook_oltp.album a On t.AlbumId = a.AlbumId
    Left Join chinook_oltp.artist ar On a.ArtistId = ar.ArtistId
    Left Join chinook_oltp.genre g On t.GenreId = g.GenreId;
    
    Alter Table chinook_olap.Track_Dim
    Add Primary Key (TrackId),
    Add Column Created_at DateTime Default Current_Timestamp,
    Add Column Updated_at DateTime Default Current_Timestamp On Update Current_Timestamp;
End //

DELIMITER ;

CALL Create_Track_Dim();

DELIMITER //

Drop Procedure If Exists Create_Date_Dim //
Create Procedure Create_Date_Dim()
Begin
    Declare start_date DATE;
    Declare end_date DATE;
    
    Select MIN(InvoiceDate), MAX(InvoiceDate) Into start_date, end_date
    FROM chinook_oltp.invoice;
    
    Set start_date = MAKEDATE(Year(start_date), 1);  
    Set end_date = MAKEDATE(Year(end_date), 365);    

    Drop Table If Exists chinook_olap.Date_Dim;
    Create Table chinook_olap.Date_Dim (
        DateId Int Primary Key,
        FullDate Date,
        Year Int,
        Quarter Int,
        Month Int,
        MonthName VarChar(20),
        WeekOfYear Int,
        DayOfWeek Int,
        DayName VarChar(10),
        IsWeekend Boolean
    );
    While start_date <= end_date Do
        Insert Into chinook_olap.Date_Dim 
        Values (
            Date_format(start_date, '%Y%m%d'),
            start_date,
            Year(start_date),
            Quarter(start_date),
            Month(start_date),
            MonthName(start_date),
            WeekOfYear(start_date),
            DayOfWeek(start_date),
            DayName(start_date),
            If(DayOfWeek(start_date) In (1,7), True, False)
        );
        Set start_date = Date_Add(start_date, Interval 1 Day);
    End While;
    
END //

DELIMITER ;

CALL Create_Date_Dim();

DELIMITER //

										# Creating Our FACT TABLE

Drop Procedure If Exists Create_Invoice_Fact //
Create Procedure Create_Invoice_Fact()
Begin
	Drop Table If Exists chinook_olap.Invoice_Fact;
    Create Table chinook_olap.Invoice_Fact (
		InvoiceID Int,
        CustomerID Int,
        TrackID Int,
        SaleDateID Int,
        TotalQuantity Int,
        TotalAmount Decimal(10, 2),
		BillingCity VarChar(50),
		BillingState VarChar(50),
		BillingCountry VarChar(50),
		BillingPostalCode VarChar(20),
        Primary Key (InvoiceID, TrackID),
        Foreign Key (CustomerID) References chinook_olap.customer_dim(CustomerId),
        Foreign Key (TrackID) References chinook_olap.track_dim(TrackId),
        Foreign Key (SaleDateID) References chinook_olap.date_dim(DateId)
	);
    
	Insert Into chinook_olap.Invoice_Fact (InvoiceID, CustomerID, TrackID, SaleDateID, TotalQuantity, TotalAmount, BillingCity, BillingState, BillingCountry, BillingPostalCode)
	Select 
		i.InvoiceId,
		cdim.CustomerId,
		tdim.TrackId,
		ddim.DateId AS SalesDateID,
		il.Quantity AS TotalQuantity,
		(il.UnitPrice * il.Quantity) AS TotalAmount,
		i.BillingCity,
		i.BillingState,
		i.BillingCountry,
		i.BillingPostalCode
    From 
		chinook_oltp.Invoice i
	Join 
		chinook_oltp.InvoiceLine il On i.InvoiceId = il.InvoiceId
	Join 
		chinook_olap.customer_dim cdim On i.CustomerId = cdim.CustomerId
	Join    
		chinook_olap.track_dim tdim On il.TrackId = tdim.TrackId
	Join 
		chinook_olap.Date_Dim ddim On Date(i.InvoiceDate) = ddim.FullDate;
END //

DELIMITER ;

CALL Create_Invoice_Fact();

						#Creating Data Mart for Business Intelligence Team

Create or Replace View Chinook_Datamart As
Select
    ft.InvoiceID,
    ft.CustomerID AS Fact_CustomerID, 
    ft.TrackID AS Fact_TrackID,       
    ft.SaleDateID,
    ft.TotalQuantity,
    ft.TotalAmount,

    cdim.CustomerId, 
    cdim.FirstName,
    cdim.LastName,
    cdim.Address,
    cdim.PostalCode,
    cdim.Phone,
    cdim.Fax,
    cdim.Email,

    ddim.DateId,
    ddim.FullDate,
    ddim.Year,
    ddim.Quarter,
    ddim.Month,
    ddim.MonthName,
    ddim.WeekOfYear,
    ddim.DayOfWeek,
    ddim.DayName,
    ddim.IsWeekend,

    tdim.TrackId,
    tdim.TrackName,
    tdim.Composer,
    tdim.Milliseconds,
    tdim.Bytes,
    tdim.UnitPrice,
    tdim.ArtistID,
    tdim.ArtistName,
    tdim.AlbumID,
    tdim.AlbumTitle,
    tdim.GenreID,
    tdim.GenreName
From chinook_olap.invoice_fact ft
Left Join chinook_olap.customer_dim cdim On ft.CustomerID = cdim.CustomerId
Left Join chinook_olap.date_dim ddim On ft.SaleDateID = ddim.DateId
Left Join chinook_olap.track_dim tdim On ft.TrackID = tdim.TrackId;

 Select * from chinook_datamart Limit 10;
        
    






