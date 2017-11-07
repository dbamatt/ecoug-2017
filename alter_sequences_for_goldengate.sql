/* #################################

   Before running, connect as sys
   and run the below to grant
   required privs to the running user

################################# */

declare
  cursor grant_list (grantee_in varchar) is
    select 'grant select on '||sequence_owner||'.'||sequence_name||' to '||grantee_in run_this 
    from dba_sequences
    where sequence_owner in ('SCHEMA1','SCHEMA2','SCHEMA3');
  grantee_user varchar2(30) := 'RUNNING_USER';
begin
  for x in grant_list (grantee_user)
  loop
    execute immediate x.run_this;
  end loop;
end;
/

grant select on dba_sequences to running_user;
grant alter any sequence to running_user;



/* #################################

   This is the actual procedure

################################# */


-- Procedure: modify_seq
--            This will modify sequences into to odd or even, depending on input
--            And it will ensure that increment is set to 2
--
-- Parameters: ownr_in    : sequence owner to be modified
--             oddeven_in : odd|even <-- your selection
--
-- Note: The owner of this proc needs to have select granted on all sequences
--       that will be checked and modified, as well as explicit grants on
--       (select on) dba_sequences and the alter any sequence sys priv.
--
-- Author: magay@cisco.com
-- Date:   20-SEP-2016 

create or replace procedure modify_seq (ownr_in in varchar2, oddeven_in in varchar2) as

  seq          varchar2(100);
  seq_nextval1 number;
  seq_nextval2 number;
  oddeven_curr varchar2(4);
  max_len      integer;
  max_inc      integer;
  max_lst      integer;
  inc          integer;
  x            integer := 0;
  error_chk    integer := 0;

  --debug_flag   varchar2(1) := 'Y'; -- set to 'Y' to run without changing anything
  debug_flag   varchar2(1) := 'N';   -- set to 'N' to change sequences during run

  cursor seq_name is 
    select sequence_name, increment_by inc, last_number
    from dba_sequences 
    where sequence_owner = upper(ownr_in)
      --and sequence_name like 'TEST%'           -- this is just in here to ensure we only hit testing sequences (remove it when using in prod)
    ;
    
  procedure print_report (hdr in varchar2) is
  begin
    dbms_output.new_line;
    dbms_output.put_line ('++++++++++ '||hdr||' ++++++++++');
    dbms_output.new_line;
    for s in seq_name
    loop
      dbms_output.put (rpad (s.sequence_name, max_len+4));
      dbms_output.put ('increment by: '||rpad (s.inc, max_inc));
      -- Show an error warning if inc != 2
      if s.inc != 2 then
        -- That's it, we have a problem so no point reporting more than this
        dbms_output.put (' !X!  ');
        error_chk := error_chk + 1;
      else
        dbms_output.put ('      ');
        -- Well, inc is okay, but let's check nextval to make sure we have the correct odd|even setting
        execute immediate 'select '||ownr_in||'.'||s.sequence_name||'.nextval from dual' into seq_nextval1;
        select decode(mod (s.last_number, 2), 1, 'odd', 'even') into oddeven_curr from dual;
        dbms_output.put ('nextval: '||rpad (oddeven_curr,4));
        -- Show an error warning odd|even doesn't match what was requested
        if oddeven_curr != oddeven_in then 
          dbms_output.put (' !X!');
          error_chk := error_chk + 1;
        end if;
      end if;
      dbms_output.new_line;
    end loop;
    dbms_output.new_line;
    dbms_output.put_line ('+++++++++++'|| rpad ('+', length(hdr), '+') ||'+++++++++++');
  end print_report;
  
  procedure log_output (msg_in in varchar2) is
  begin
    if x = 0 then
      dbms_output.new_line;
      dbms_output.put_line (rpad(seq, max_len) || ' --- ' || msg_in);
      x := 1;
    else
      dbms_output.put_line (rpad('   ', max_len) || '     ' || msg_in);
    end if;
  end log_output;
  
  procedure run_me (stmt in varchar2) is
  begin
    if debug_flag != 'Y' then
      execute immediate stmt;
    --else log_output ('... execute immediate: '||stmt||' ...');
    end if;
  end run_me;
  
  function confirm_me return varchar is
    tmp_nextval number;
    conf_txt    varchar2(255);
  begin
    execute immediate 'select '||ownr_in||'.'||seq||'.nextval from dual' into tmp_nextval;
    select '[CONFIRMATION]: '||sequence_owner||'.'||sequence_name||' increment by: '||increment_by||' nextval: '||tmp_nextval into conf_txt
      from dba_sequences where sequence_owner = upper(ownr_in) and sequence_name = seq;
    return conf_txt;
  end confirm_me;

begin

  dbms_output.enable(1000000);

  if oddeven_in not in ('odd','even') then 
    log_output ('Second parameter must be a value for: odd|even');
    return; 
  end if;

  select max(length(sequence_name)), max(length(to_char(increment_by))), max(length(to_char(last_number)))
  into max_len, max_inc, max_lst
  from dba_sequences 
  where sequence_owner = upper(ownr_in)
    --and sequence_name like 'TEST%'           -- this is just in here to ensure we only hit testing sequences (remove it when using in prod)
    ;
  
  if max_len is null then
    seq := upper (ownr_in);  -- just setting this to make log output do what I want
    max_len := length(seq);
    log_output ('Not a valid sequence owner');
    return;
  end if;

  dbms_output.put_line ('RUNNING ON ALL SEQUENCES OWNED BY: '||upper(ownr_in));

  if debug_flag = 'Y' then
    dbms_output.new_line;
    dbms_output.put_line ('( ... running in debug mode, no changes will be made ... )');
  end if;
  
  print_report ('Initial assessment of sequences');
  
  if error_chk = 0 then
    dbms_output.new_line;
    dbms_output.put_line ('Everything looks okay, exiting now...'); 
    return;
  end if;
  
  for s in seq_name
  loop

    x := 0;
    seq := s.sequence_name;
    execute immediate 'select '||ownr_in||'.'||seq||'.nextval from dual' into seq_nextval1;
    select decode(mod (seq_nextval1, 2), 1, 'odd', 'even') into oddeven_curr from dual;
    
    -- nextval does not match requested oddeven state, so adjust and make sure inc is 2
    if oddeven_curr != oddeven_in then

      log_output ('nextval is '||oddeven_curr||' ('||seq_nextval1||'), but you''ve requested '||oddeven_in||', so we need to fix that');
      log_output ('set inc to 1, get new nextval, then set increment to 2 (so all the rest will be '||oddeven_in||')');
        if s.inc != 2 then
          log_output ('also your current increment is '||s.inc||' so that will get fixed, too, during this process');
        end if;
        run_me ('alter sequence '||ownr_in||'.'||seq||' increment by 1');
        execute immediate 'select '||ownr_in||'.'||seq||'.nextval from dual' into seq_nextval2;
        run_me ('alter sequence '||ownr_in||'.'||seq||' increment by 2');
      log_output (confirm_me);

    -- nextval matches requested oddeven state, but inc != 2, so fix that
    elsif s.inc != 2 then

      log_output ('nextval is '||oddeven_curr||' ('||seq_nextval1||'), and you''ve requested '||oddeven_in||' so that''s good');    
      log_output ('however, increment is set to: '||s.inc||', changing it to 2');
        run_me ('alter sequence '||ownr_in||'.'||seq||' increment by 2'); 
      log_output (confirm_me);

    -- everything looks good, skip this one
    else

      log_output ('nextval is '||oddeven_curr||' ('||seq_nextval1||'), you''ve requested '||oddeven_in||', and increment is set to '||s.inc||', everything is okay');    

    end if; 

  end loop; 

  print_report ('Final assessment of sequences');
  
exception

  when others then dbms_output.put_line (sqlerrm);

end modify_seq;
/






/* #################################

        Run it

################################# */


-- second parameter, odd|even
exec modify_seq ('SCHEMA1','odd');




/* #################################

        Create test objects

################################# */

-- drop all
drop sequence test_seq_inc_by_1;
drop sequence test_seq_inc_by_100;
drop sequence test_seq_odd;
drop sequence test_seq_even;

-- create new ones
create sequence test_seq_inc_by_1 minvalue 1 maxvalue 999999999 increment by 1 start with 1 cache 20 nocycle;
create sequence test_seq_inc_by_100 minvalue 1 maxvalue 999999999 increment by 100 start with 101 cache 20 nocycle;
create sequence test_seq_odd minvalue 99 maxvalue 999999999 increment by 2 start with 99 cache 20 nocycle;
create sequence test_seq_even minvalue 98 maxvalue 999999999 increment by 2 start with 98 cache 20 nocycle;



