/****
description:
Pulls business rules from a table and create a CTE for each business rule. The table which is being checked for errors is assumed to be generically types (i.e. )

parameters:
validation_db - Mandatory. database context for table validation
validation_schema - Mandatory. schema context for table validation
validation_table - Mandatory. table to validate rule against

returns:
string - "success" or failure message

20210119 - gmullen - initial draft
20210125 - gmullen - reconfigure for JSON error column
20210203 - gmullen - Add summary stats and fix table loop to include multiple tables. Moved PK to validation metadata table
****/
CREATE OR REPLACE PROCEDURE DATA_VALIDATION(validation_db varchar, validation_schema varchar, validation_table varchar)
RETURNS VARIANT
LANGUAGE JAVASCRIPT
AS
$$
//Get Tables to validate from validation table
var rs_tables = snowflake.createStatement({
	sqlText: "SELECT DISTINCT upper(database_name) AS DATABASE_NAME, UPPER(schema_name) AS SCHEMA_NAME, UPPER(table_name) AS TABLE_NAME"
			+ ", upper(PRIMARY_KEY_COLUMN_NAME) as PRIMARY_KEY_COLUMN_NAME FROM "
			+ VALIDATION_DB + "." + VALIDATION_SCHEMA + "." + VALIDATION_TABLE
}).execute();

//setup return value
var return_results = [];
var table_count = 0;

//BEGIN TABLE LOOP - INCLUDES ALL TABLES TO VALIDATE FROM VALIDATION_TABLE
while (rs_tables.next()) {
	//FOR EACH DB.SCHEMA.TABLE GET TABLE INFO
	db_name = rs_tables.getColumnValue('DATABASE_NAME');
	schema_name = rs_tables.getColumnValue('SCHEMA_NAME');
	table_name = rs_tables.getColumnValue('TABLE_NAME');
	primary_key_column_name = rs_tables.getColumnValue('PRIMARY_KEY_COLUMN_NAME');
	var is_first_cte = true;
	var sql_cte_text = "";
	var sql_join_text = "";
	var rule_col = "";
	var where_clause = "";
	var rule_count = 0;

	//GET ALL COLUMNS FROM CURRENT TABLE TO VALIDATE. USE THIS TO BUILD UNIQUE MD5 HASH IF NO PK
	snowflake.createStatement({
		"sqlText": "SHOW COLUMNS IN TABLE \"" + db_name + "\".\"" + schema_name + "\".\"" + table_name + "\";"
	}).execute();
	var stmt_getcolumn_list = snowflake.createStatement({
		sqlText: "SELECT \"column_name\" AS NAME FROM TABLE(RESULT_SCAN(LAST_QUERY_ID())) where \"kind\" = 'COLUMN';"
	});

	//IF NO PRIMARY KEY GENERATE ONE BY COMBINING ALL COLUMNS WITH MD5
	if (primary_key_column_name == null || primary_key_column_name == undefined) {
		var res_columns = stmt_getcolumn_list.execute();
		var md5_column = "";
		var is_first_column = true;
		while (res_columns.next()) {
			md5_attribute = "NVL(" + res_columns.getColumnValue(1) + "::varchar,\'\')";
			if (is_first_column) {
				is_first_column = false;
			} else {
				md5_attribute = "||" + md5_attribute;
			}
			md5_column = md5_column + md5_attribute;
		}
		join_pk_col = 'md5_hash';
		md5_column = " md5(" + md5_column + ") as " + join_pk_col + " ";
		add_md5_col = true;

	} else {
		join_pk_col = primary_key_column_name;
		md5_column = join_pk_col;
		add_md5_col = false;
	}
	//END - GET ALL COLUMNS FROM CURRENT TABLE TO VALIDATE. USE THIS TO BUILD UNIQUE MD5 HASH IF NO PK

	// GET VALIDATION RULES FOR CURRENT TABLE
	var stmt_getdb_list = snowflake.createStatement({
		sqlText: "SELECT * from " + VALIDATION_DB + "." + VALIDATION_SCHEMA + "." + VALIDATION_TABLE +
			" where database_name ILIKE '" + db_name + "' AND schema_name ILIKE '" + schema_name + "' AND table_name ILIKE '" + table_name + "';"
	});
	var rs_rules = stmt_getdb_list.execute();

	//GENERATE CTE FOR EACH RULE
	while (rs_rules.next()) {
		rule_count+=1;
		//check valid syntax
		rule_name = rs_rules.getColumnValue('RULE_NAME');
		db_name = rs_rules.getColumnValue('DATABASE_NAME');
		schema_name = rs_rules.getColumnValue('SCHEMA_NAME');
		table_name = rs_rules.getColumnValue('TABLE_NAME');
		field_name = rs_rules.getColumnValue('FIELD_NAME');
		where_condition = rs_rules.getColumnValue('WHERE_CONDITION');

		//BUILD CTE AND ERROR_COLUMN
		if (is_first_cte) {
			sql_cte_text = "WITH ";
			rule_col = "OBJECT_CONSTRUCT('" + rule_name + "'," + rule_name;
		} else {
			sql_cte_text = sql_cte_text + "\n\n, ";
			rule_col += ",'" + rule_name + "'," + rule_name;
		}

		sql_cte_text = sql_cte_text + rule_name + " AS ( SELECT 1 AS " + rule_name + ", " + md5_column + "\nFROM " + db_name + "." + schema_name + "." + table_name +
			"\nWHERE " + where_condition + ")";

		//Build SQL. Check if first criteria
		if (is_first_cte) {
			sql_join_text = "\nLEFT JOIN ";
			where_clause = "\nWHERE " + rule_name + " IS NOT NULL";
		} else {
			sql_join_text += "\nLEFT JOIN ";
			where_clause += "\nOR " + rule_name + " IS NOT NULL";
		}
		sql_join_text = sql_join_text + rule_name + "\n\tON " + rule_name + "." + join_pk_col + " = " + table_name + "." + join_pk_col;
		is_first_cte = false;
	} //END GENERATE CTE FOR EACH RULE

	//BUILD AND JOIN FINAL QUERY
	sql_cte_text = sql_cte_text + "\n\nSELECT current_timestamp() validated_timestamp," + rule_col + ") error_json," + table_name + ".* FROM (\nSELECT *" ;
	if (add_md5_col) { sql_cte_text += "," + md5_column;}
	sql_cte_text += "\nFROM " + db_name + "." + schema_name + "." + table_name + ") " + table_name + sql_join_text + where_clause;

	var error_table_name = "ERROR_" + db_name + "_" + schema_name + "_" + table_name;

	//CHECK IF ERROR TABLE EXISTS. CREATE OR INSERT.
	table_check_res = snowflake.createStatement({
		sqlText: "select * from " + db_name + ".information_schema.tables where table_name ilike '" + error_table_name + "';"
	}).execute();

	if (table_check_res.getRowCount() == 0) {
		sql_cte_text = "CREATE TABLE IF NOT EXISTS " + error_table_name + " AS " + sql_cte_text;
	} else {
		sql_cte_text = "INSERT INTO " + error_table_name + " " + sql_cte_text;
	}
	//END - CHECK IF ERROR TABLE EXISTS. CREATE OR INSERT.

	//EXECUTE RULES QUERY
	rules_results = snowflake.createStatement({sqlText: sql_cte_text}).execute();

	//GENERATE JOB STATISTICS FOR CURRENT TABLE
	total_rec_results = snowflake.createStatement({sqlText: "select count(*) from " + table_name}).execute();
	total_rec_results.next()
	total_rec_processed = total_rec_results.getColumnValue(1);
	total_errors_results = snowflake.createStatement({sqlText: "select count(*) from " + error_table_name + " where validated_timestamp = (select max(validated_timestamp) from "+error_table_name+")"}).execute();
	total_errors_results.next()
	total_errors_processed = total_errors_results.getColumnValue(1);
	job_table_name = "JOB_SUMMARY";

	//CHECK IF JOB SUMMARY TABLE EXISTS. CREATE OR INSERT.
	job_check_res = snowflake.createStatement({
		sqlText: "select * from " + db_name + ".information_schema.tables where table_name ilike '" + job_table_name + "';"
	}).execute();

	sql_job_text = "SELECT " + total_rec_processed + " records_processed," + total_errors_processed + " records_w_errors, current_timestamp() date_processed, '" +  db_name +"' db_name,'" + schema_name + "' schema_name,'" + table_name + "' table_name,"+ rule_count+" num_of_rules";
	if (job_check_res.getRowCount() == 0) {
		sql_job_text = "CREATE TABLE IF NOT EXISTS " + job_table_name + " AS " + sql_job_text;
	} else {
		sql_job_text = "INSERT INTO " + job_table_name + " " + sql_job_text;
	}

	//EXECUTE JOB STATISTICS
	snowflake.createStatement({	sqlText: sql_job_text}).execute();
	//END - GENERATE JOB STATISTICS FOR CURRENT TABLE

	//POPULATE RETURN VALUE
	table_count += 1;
	return_results.push("Error Table_" + table_count + ": " + error_table_name);

} // while(rs_tables.next())
// END TABLE LOOP

	return_results.push("Job Summary Table: " + job_table_name);
	return  return_results;
$$;