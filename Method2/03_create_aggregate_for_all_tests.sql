/*
    Here is an example of aggregating all errors into one location. It involves
    manually adding each test in as a UNION ALL into an ever growing list.
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