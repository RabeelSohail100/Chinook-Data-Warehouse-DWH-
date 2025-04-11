# Chinook Data Warehouse (DWH)

This project sets up a Data Warehouse (DWH) for the **Chinook Database**. It uses a **Star Schema** with dimension tables for **Customer**, **Track**, and **Date**, along with a **Fact Table** for **Invoices**. A view (`Chinook_Datamart`) is created to combine the fact and dimension tables for reporting.

# Project Structure
scripts/: Contains SQL scripts for the extraction, transformation, and loading (ETL) process. This includes:

Scripts to extract data from the Chinook OLTP schema.

Transformation logic to load data into the Chinook OLAP schema (Star Schema).

SQL queries to create dimension tables (customer_dim.sql, track_dim.sql, Date_dim/sql), fact tables (invoice_fact.sql), and a Chinook_Datamart view.

diagrams/: Contains the ERD (Entity Relationship Diagram) for both the OLTP schema and the OLAP schema (Star Schema). This will help visualize how the data is structured in the OLTP system and how it is transformed into the OLAP system for reporting and analytics.
