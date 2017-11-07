select owner, table_name, length(table_name) from dba_tables
where owner in ('SCHEMA1', 'SCHEMA2', 'SCHEMA3')
order by 3 desc, 2,1;


declare
  cursor tab_list is select owner, table_name from dba_tables where owner in ('SCHEMA1', 'SCHEMA2', 'SCHEMA3');
  stmt varchar2(4000);
  tab  varchar2(100);
  trig varchar2(100);
begin
  dbms_output.enable (1000000);
  for t in tab_list
  loop
    tab := lower(t.owner||'.'||t.table_name);
    -- Set trigger name, but shorten for any tables with > 24 char names
    if t.table_name = 'SOMETHING_REALLY_REALLY_REALLY_LONG' then
      trig := lower (t.owner||'.'||'SOMETHING_REALLY_LONG'||'_oggts');
    end if;
    stmt := 'alter table '||tab||' add (ogg_insert_ts timestamp)';
    dbms_output.put_line (stmt);
    execute immediate stmt;
    stmt := 'alter table '||tab||' add (ogg_update_ts timestamp)';
    dbms_output.put_line (stmt);
    execute immediate stmt;
    stmt := 'update '||tab||' set (ogg_insert_ts, ogg_update_ts) = (select trunc (systimestamp), trunc (systimestamp) from dual)';
    dbms_output.put_line (stmt);
    execute immediate stmt;
    stmt := 'commit';
    dbms_output.put_line (stmt);
    execute immediate stmt;
    stmt := 'alter table '||tab||' modify (ogg_insert_ts timestamp default systimestamp not null)';
    dbms_output.put_line (stmt);
    execute immediate stmt;
    stmt := 'alter table '||tab||' modify (ogg_update_ts timestamp default systimestamp not null)';
    dbms_output.put_line (stmt);
    execute immediate stmt;
    stmt := 'create or replace trigger '||trig||'
  before insert or update on '||tab||'
  for each row
  when (user != ''GGUSER'')
begin
  if inserting then
    :new.ogg_insert_ts := systimestamp;
    :new.ogg_update_ts := systimestamp;
  end if;
  if updating then
    :new.ogg_update_ts := systimestamp;
  end if;
end;';
    dbms_output.put_line (stmt);
    execute immediate stmt;
  end loop;
end;
/



