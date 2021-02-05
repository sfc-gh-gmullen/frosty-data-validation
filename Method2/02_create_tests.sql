/*
    The goal of all of the views is to only return errors. Hopefully, if all is
    well with your data, the views will return 0 rows.

    The following views are four individual tests:
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