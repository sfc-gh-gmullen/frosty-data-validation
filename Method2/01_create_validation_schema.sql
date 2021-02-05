/*
    Create a schema that will hold all your validation views (1 view for each test)
*/

CREATE SCHEMA IF NOT EXISTS validation;

/*
    Alternatively, for an organization that might have hundreds of tests, you
    may want to create an entire "validation" database, with many schemas for
    additional organization. For example:

    CREATE DATBASE validation;
    CREATE SCHEMA citibike_valiadtion;
    CREATE SCHEMA weather_validation;
*/