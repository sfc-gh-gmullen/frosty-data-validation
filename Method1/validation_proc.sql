/****
description:
Pulls business rules from a table and create a CTE for each business rule. The table which is being checked for errors is assumed to be generically types (i.e. )

parameters:
validation_db - Mandatory. database context for table validation
validation_schema - Mandatory. schema context for table validation
validation_table - Mandatory. table to validate rule against
primary_key_column_name - Optional. the name of the unique identifier. If NULL, procedure generates an MD5 hash for the record

returns:
string - "success" or failure message

20200119 - gmullen - initial draft
****/
CREATE OR REPLACE PROCEDURE DATA_VALIDATION(validation_db varchar, validation_schema varchar, validation_table varchar, primary_key_column_name varchar)
  RETURNS VARCHAR
  LANGUAGE JAVASCRIPT 
  AS
$$       
  //Get Validation Tables
    var rs_tables = snowflake.createStatement( { sqlText: "SELECT DISTINCT upper(database_name) AS DATABASE_NAME, UPPER(schema_name) AS SCHEMA_NAME, UPPER(table_name) AS TABLE_NAME FROM " + VALIDATION_DB + "." + VALIDATION_SCHEMA + "." + VALIDATION_TABLE} ).execute();
    //BEGIN TABLE LOOP
    while(rs_tables.next())
    {
      //FOR EACH DB.SCHEMA.TABLE GET TABLE INFO
      db_name = rs_tables.getColumnValue('DATABASE_NAME');
      schema_name = rs_tables.getColumnValue('SCHEMA_NAME');
      table_name = rs_tables.getColumnValue('TABLE_NAME');   
      
      //GET ALL COLUMNS FROM CURRENT TABLE
      snowflake.createStatement( { "sqlText": "SHOW COLUMNS IN TABLE \"" + db_name + "\".\"" + schema_name + "\".\"" + table_name + "\";" } ).execute();
      var stmt_getcolumn_list = snowflake.createStatement( { sqlText: "SELECT \"column_name\" AS NAME FROM TABLE(RESULT_SCAN(LAST_QUERY_ID())) where \"kind\" = 'COLUMN';"} );
            
      //IF NO PRIMARY KEY GENERATE ONE BY COMBINING ALL COLUMNS WITH MD5 
      if(PRIMARY_KEY_COLUMN_NAME == null || PRIMARY_KEY_COLUMN_NAME == undefined)
      {
        var res_columns = stmt_getcolumn_list.execute();
        var md5_column ="";
        var is_first_column = true;
        while (res_columns.next()) {
          md5_attribute = "NVL(" + res_columns.getColumnValue(1) + "::varchar,\'\')";
          if (is_first_column) {
            is_first_column = false;
          }
          else {
            md5_attribute = "||" + md5_attribute;
          }
          md5_column = md5_column + md5_attribute;
        }
          md5_column = " md5(" + md5_column + ") as md5_hash "; 
      }  
      else
      {
        md5_column = PRIMARY_KEY_COLUMN_NAME;
      }
    // get validation rules
    var stmt_getdb_list = snowflake.createStatement( { sqlText: "SELECT * from " + VALIDATION_DB + "." + VALIDATION_SCHEMA + "." + VALIDATION_TABLE + " where table_name ILIKE '" + table_name + "';"} );                            

    var rs_rules = stmt_getdb_list.execute();
        
    var is_first_cte = true;
    var sql_cte_text ="";
    var sql_join_text ="";
    var rule_col ="";
    var where_clause="";

        
    while (rs_rules.next()) {  
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
      } 
      else {
        sql_cte_text = sql_cte_text + "\n\n, "; 
        rule_col += ",'" + rule_name + "'," + rule_name;
      }
      
      sql_cte_text = sql_cte_text + rule_name + " AS ( SELECT 1 AS " + rule_name + ", " + md5_column + "\nFROM " + db_name + "." + schema_name + "." + table_name + "\nWHERE " + where_condition + ")"

      if (is_first_cte) { sql_join_text = "\nLEFT JOIN ";where_clause = "\nWHERE " + rule_name + " IS NOT NULL";} 
      else {sql_join_text += "\nLEFT JOIN ";where_clause += "\nOR " + rule_name + " IS NOT NULL";}
      sql_join_text = sql_join_text + rule_name + "\n\tON " + rule_name + ".md5_hash = "+ table_name + ".md5_hash";
                
      is_first_cte = false;                   
     }//END RULES
     
    sql_cte_text = sql_cte_text + "\n\nSELECT current_timestamp() validated_timestamp," + rule_col + ") error_json," + table_name+".* FROM (\nSELECT *," + md5_column + "\nFROM " + table_name +") " + table_name + sql_join_text + where_clause;
    var error_table_name = "ERROR_" + table_name;
    
    //CHECK IF TABLE EXISTS. CREATE OR INSERT.
    table_check_res = snowflake.createStatement( { sqlText: "select * from " + db_name + ".information_schema.tables where table_name ilike '"+error_table_name+"';" } ).execute();  

    if (table_check_res.getRowCount() == 0) {
      sql_cte_text = "CREATE TABLE IF NOT EXISTS " + error_table_name + " AS " + sql_cte_text;
    }
    else
    {
      sql_cte_text = "INSERT INTO " + error_table_name + " " + sql_cte_text;
    }
      try{
          snowflake.createStatement( { sqlText: sql_cte_text } ).execute();                                  
          return error_table_name;
       }
       catch(e){
          return e;
       }
    } // while(rs_tables.next())
    // END TABLE LOOP
$$;
  