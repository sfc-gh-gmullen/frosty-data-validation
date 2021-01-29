//*************
create table scaffolding to support metadata for validation stored procedure

20200119 - Intial draft
***************//
//USE APPROPRIATE CONTROL DATABASE
//master table
create schema validation;

create table trips clone public.trips;

create or replace table master_tables(name varchar,schema varchar);
insert into master_tables values ('trips','validation');


create or replace table validation_rules(rule_name varchar, database_name varchar, schema_name varchar, table_name varchar, field_name varchar, where_condition varchar, error_message varchar);
insert into validation_rules values('too_long','gmullen_db','validation','trips', 'tripduration','tripduration > (60*60*24)', 'duration cannot exceed 24 hours');
insert into validation_rules values('invalid_age','gmullen_db','validation','trips', 'birth_year','date_from_parts( birth_year,month(current_Date()),day(current_date())) < dateadd(year,-150,current_date())', 'cannot be older than 150 years');
insert into validation_rules values('invalid_date','gmullen_db','validation','trips', 'starttime','IFF(TRY_TO_DATE(STARTTIME::VARCHAR) IS NOT NULL,FALSE,TRUE)', 'cannot be older than 150 years');
select * from validation_rules;