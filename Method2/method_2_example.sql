/*
    Create a schema that will hold all your validation views (1 view for each
    test)
*/

CREATE SCHEMA IF NOT EXISTS validation;

/*
    Alternatively, for an organization that might have hundreds of tests, you may want to
    create an entire "validation" database, with many schemas for additional
    organization. For example:

    CREATE DATBASE validation;
    CREATE SCHEMA citibike_valiadtion;
    CREATE SCHEMA weather_validation;
*/

/*
    The goal of all of the views is to only return errors. Hopefully, if all is
    well with your data, the views will return 0 rows.

    The following views are three individual tests:
    1) Return trips that are longer than 24 hours
    2) Return birth years that are older than 150 years
    3) Return trips where the start time was more than 25 years ago
    4) Return duplicates in the data

    Avoid using a SELECT * in your views, since you will get syntax
    errors as the underlying table adds or drops tables. If you have a primary
    key, then you likely just need to return that. In these examples, we will be
    returning the columns that make a row unique since there is no primary key.
*/

CREATE OR REPLACE VIEW validation.trips_tripduration_too_long AS
    SELECT
         starttime
        ,start_station_id
        ,bikeid
        ,tripduration
    FROM demo.trips
    WHERE tripduration > (60*60*24)
;

CREATE OR REPLACE VIEW validation.trips_inaccurate_birth_year AS
    SELECT
         starttime
        ,start_station_id
        ,bikeid
        ,birth_year
    FROM demo.trips
    WHERE YEAR(CURRENT_DATE()) - birth_year > 150
;

CREATE OR REPLACE VIEW validation.trips_inaccurate_starttime AS
    SELECT
         starttime
        ,start_station_id
        ,bikeid
    FROM demo.trips
    WHERE DATEDIFF('year', starttime, CURRENT_DATE()) > 25
;

CREATE OR REPLACE VIEW validation.trips_duplicates AS
    SELECT
         starttime
        ,start_station_id
        ,bikeid
        ,tripduration
        ,COUNT(*) AS number_of_duplicates
    FROM demo.trips
    GROUP BY 1,2,3,4
    HAVING COUNT(*) > 1
;

-- Add all additional tests here, each as an individual view


/*
    Here is an example of aggregating all errors into one location. It involves
    manually adding each test in as a UNION ALL into an ever growing list.

    TODO: Dynamically generate this view based on all views in the validation schema
*/

CREATE OR REPLACE VIEW all_errors AS
    SELECT
         'TRIPS' AS error_in_table
        ,'Trip duration cannot exceed 24 hours' AS error_message
        ,object_construct(*) AS error
    FROM validation.trips_tripduration_too_long

    UNION ALL

    SELECT
         'TRIPS' AS error_in_table
        ,'Birth year cannot exceed 150 years old' AS error_message
        ,object_construct(*) AS error
    FROM validation.trips_inaccurate_birth_year

    UNION ALL

    SELECT
         'TRIPS' AS error_in_table
        ,'Starttime cannot exceed 25 years ago' AS error_message
        ,object_construct(*) AS error
    FROM validation.trips_inaccurate_starttime

    UNION ALL

    SELECT
         'TRIPS' AS error_in_table
        ,'Duplicates found' AS error_message
        ,object_construct(*) AS error
    FROM validation.trips_duplicates

    -- Add all views from the previous step here
;


/*
    This is an even more aggregated view that returns only one row per test
*/

CREATE OR REPLACE VIEW all_errors_aggregated AS
    SELECT
         error_in_table
        ,error_message
        ,COUNT(*) AS number_of_errors
        ,array_agg(error) AS all_errors
    FROM validation.all_errors
    GROUP BY 1,2
;

SELECT *
FROM validation.all_errors_aggregated;