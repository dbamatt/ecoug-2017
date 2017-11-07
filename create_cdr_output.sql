declare
  cursor all_tables is 
    select owner, table_name 
    from dba_tables
    where owner = 'SCHEMA_NAME' 
    order by 1;
begin
  for t in all_tables
  loop
  dbms_output.put_line ('map ' || t.owner || '.' || t.table_name || ', target ' || t.owner || '.' || t.table_name || ', &');
  dbms_output.put_line ('comparecols ( &');
  dbms_output.put_line ('on update all , &');
  dbms_output.put_line ('on delete keyincluding ( OGG_UPDATE_TS )),  &');
  dbms_output.put_line ('resolveconflict (INSERTROWEXISTS,  (default, usemax ( gg_insert_ts ))), &');
  dbms_output.put_line ('resolveconflict (UPDATEROWMISSING, (default, overwrite )), &');
  dbms_output.put_line ('resolveconflict (UPDATEROWEXISTS,  (default, usemax ( gg_update_ts ))), &');
  dbms_output.put_line ('resolveconflict (DELETEROWEXISTS,  (default, ignore)), &');
  dbms_output.put_line ('resolveconflict (DELETEROWMISSING, (default, discard));');
  dbms_output.new_line;
  dbms_output.put_line ('------');
  dbms_output.new_line;
  end loop;
end;
/