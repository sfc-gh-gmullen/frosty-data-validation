/*
    OPTIONAL: Dynamically generate the previous view based on all views in the
    validation schema by running this Stored Procudure. If you use the stored
    procedure, then you do not need to run and maintain the prior view

    SCHEDULING: You will want to schedule this (maybe once at night or run it
    manually for each new validation view you create, so the new views can be
    added to this aggregated view)
*/

CREATE OR REPLACE PROCEDURE validation.create_aggregated_validation()
  RETURNS VARCHAR
  LANGUAGE JAVASCRIPT
  AS
  $$
    var views_in_schema = snowflake.createStatement( { sqlText: "SHOW VIEWS IN SCHEMA" } ).execute();
    var all_errors = "CREATE OR REPLACE VIEW all_errors AS \n";

    while(views_in_schema.next()) {
        var view_name = views_in_schema.getColumnValue('name');
        var schema_name = views_in_schema.getColumnValue('schema_name');

        // Don't include the aggregated views
        if (view_name.toString() != 'ALL_ERRORS' & view_name.toString() != 'ALL_ERRORS_AGGREGATED' ) {
            var union_stmt = `\nSELECT '` + view_name + `' AS test_name, object_construct(*) AS error`
                              + `\nFROM ` + schema_name + `.` + view_name
                              + '\n\nUNION ALL \n';

            // Add union statement to the full all_errors statement
            all_errors = all_errors + union_stmt
        }
    }

    // Remove last UNION ALL, then run CREATE VIEW
    all_errors = all_errors.slice(0, -13);
    snowflake.createStatement( { sqlText: all_errors } ).execute();

    result = all_errors.toString();
    return result;
$$
;

CALL create_aggregated_validation();