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


/*
    Use this version if you are using the stored procedure
*/

CREATE OR REPLACE VIEW all_errors_aggregated AS
    SELECT
         test_name
        ,COUNT(*) AS number_of_errors
        ,array_agg(error) AS all_errors
    FROM validation.all_errors
    GROUP BY 1
;