create or replace package "UNIT_TEST" is

  assert_exception exception;

  pragma exception_init(assert_exception, -20901);

  /**
  * c�������� �����
  */
  type t_test_info is record(
    nm_pack  varchar2(50),
    nm_test  varchar2(50),
    pr_setup boolean,
    pr_down  boolean);
  /**
  * ������ ������
  */
  type t_test_tbl is table of t_test_info;
  /**
  * ������ �� ���������� ������
  * @param  p_pack_nm  ������������ ������ ��� ������
  * @param  p_test_nm  ������������ ��������� ����� ������ ������� ��� ������
  * @param  p_ignore_success �������� ����������� �������� ��������,
  *         �� ��������� �������� �������� �� ����������
  * @param  p_store_log ������� ���������� ���� � �������
  *         �� ��������� ������� � ������� (dbms_output)
  * ���� ��������� �� ������� �� ����� ����������� ��� �����
  */
  procedure run_test(p_pack_nm        varchar2,
                     p_test_nm        varchar2,
                     p_ignore_success boolean := true,
                     p_store_log      boolean := false);

  /**
  * �������� ������������� ���������� ������� ������ � ������ ������ ������
  */
  function get_last_run_id return number;

  procedure fail(p_message in varchar2 default '');
  procedure assert_true(p_condition in boolean,
                        p_message   in varchar2 default '');
  procedure assert_false(p_condition in boolean,
                         p_message   in varchar2 default '');

  procedure assert_equals(p_expected in varchar2,
                          p_actual   in varchar2,
                          p_message  in varchar2 default '');
  procedure assert_equals(p_expected in boolean,
                          p_actual   in boolean,
                          p_message  in varchar2 default '');
  procedure assert_equals(p_expected in date,
                          p_actual   in date,
                          p_message  in varchar2 default '');
  procedure assert_equals(p_expected in number,
                          p_actual   in number,
                          p_message  in varchar2 default '');
  procedure assert_equals(p_expected in number,
                          p_actual   in number,
                          p_range    in number,
                          p_message  in varchar2 default '');
  procedure assert_not_equals(p_expected in varchar2,
                              p_actual   in varchar2,
                              p_message  in varchar2 default '');
  procedure assert_not_equals(p_expected in boolean,
                              p_actual   in boolean,
                              p_message  in varchar2 default '');
  procedure assert_not_equals(p_expected in date,
                              p_actual   in date,
                              p_message  in varchar2 default '');
  procedure assert_not_equals(p_expected in number,
                              p_actual   in number,
                              p_message  in varchar2 default '');
  procedure assert_not_equals(p_expected in number,
                              p_actual   in number,
                              p_range    in number,
                              p_message  in varchar2 default '');
  procedure assert_null(p_actual  in varchar2,
                        p_message in varchar2 default '');
  procedure assert_null(p_actual in date, p_message in varchar2 default '');
  procedure assert_null(p_actual  in boolean,
                        p_message in varchar2 default '');
  procedure assert_null(p_actual  in number,
                        p_message in varchar2 default '');
  procedure assert_not_null(p_actual  in varchar2,
                            p_message in varchar2 default '');
  procedure assert_not_null(p_actual  in boolean,
                            p_message in varchar2 default '');
  procedure assert_not_null(p_actual  in date,
                            p_message in varchar2 default '');
  procedure assert_not_null(p_actual  in number,
                            p_message in varchar2 default '');
end unit_test;
/
create or replace package body "UNIT_TEST" is

  c_result_success constant number := 1;

  c_result_fail constant number := 0;

  c_label_expect constant varchar2(50) := '�������';

  c_label_return constant varchar2(50) := '��������';

  /**
  * ������������� �������
  */
  g_id_run number;
  /**
  * ����� ������ �������
  */
  g_dt_run date;
  /**
  * ������� ����
  */
  g_test t_test_info;
  /**
  * ����������� �������� ��������
  */
  g_ignore_success boolean;
  /**
  * ����������� � �� ��� �������
  */
  g_store_log boolean;

  /**
  * ������ ���������� � ���
  * @param p_result  ��� ����������
  * @param p_message ��������� �����
  * @param p_addition �������������� ����������
  */
  procedure log(p_result number, p_message varchar2, p_addition varchar2) is
    pragma autonomous_transaction;
  begin
    -- ���� ����� �� ���, �� ������ �������� ����������
    if g_test.nm_pack is null and p_result = c_result_fail then
      raise_application_error(-20901, p_message || chr(13) || p_addition);
    end if;
    -- ���� ���������� �������� �������� �� �������� ������ ����
    if not (g_ignore_success and p_result = c_result_success) then
      if g_store_log then
        insert into unit_test_log
          (id_run,
           nm_package,
           nm_test,
           pr_success,
           nm_msg,
           dt_run,
           nm_addition)
        values
          (g_id_run,
           g_test.nm_pack,
           g_test.nm_test,
           p_result,
           substr(p_message, 1, 4000),
           g_dt_run,
           substr(p_addition, 1, 4000));
        commit;
      else
        if p_result = c_result_fail then
          dbms_output.put('ERROR');
        else
          dbms_output.put('SUCCESS');
        end if;
        dbms_output.put(' ' || g_test.nm_pack || '.' || g_test.nm_test || ' ' ||
                        p_message || ' ' || p_addition);
        dbms_output.put_line(null);
      end if;
    end if;
  end;

  function bool_to_str(p_val boolean) return varchar2 is
  begin
    if p_val then
      return 'TRUE';
    elsif p_val is null then
      return 'NULL';
    else
      return 'FALSE';
    end if;
  end bool_to_str;

  function date_to_str(p_val date) return varchar2 is
  begin
    if p_val is null then
      return 'NULL';
    else
      return to_char(p_val, 'dd.mm.yyyy');
    end if;
  end;

  function num_to_str(p_val number) return varchar2 is
  begin
    if p_val is null then
      return 'NULL';
    else
      return to_char(p_val);
    end if;
  end;

  /**
  * �������� ������ ������ �� �����
  * @param  p_pack_nm  ������������ ������ ��� ������
  * @param  p_test_nm  ������������ ��������� ����� ������ ������ ��� ������
  * @return  ������ ������ ������������ �����������, ���� �������� ��� ��������� ������� �� ������ ������ ������ ������ �����
  */
  function get_test_info(p_pack_nm varchar2, p_test_nm varchar2)
    return t_test_tbl is
    v_result_test t_test_tbl := t_test_tbl();
    v_test        t_test_info;
  begin
    for rw in (select t.object_name    as package_nm,
                      t.procedure_name as test_nm,
                      s.procedure_name as setup_nm,
                      d.procedure_name as down_nm
                 from user_procedures t
                 left join user_procedures s
                   on s.object_name = t.object_name
                  and s.procedure_name = 'S_' || substr(t.procedure_name, 3)
                 left join user_procedures d
                   on d.object_name = t.object_name
                  and d.procedure_name = 'D_' || substr(t.procedure_name, 3)
                where t.object_type = 'PACKAGE'
                  and substr(t.object_name, 1, 2) = 'T_'
                  and substr(t.procedure_name, 1, 2) = 'T_'
                  and t.object_name = nvl(upper(p_pack_nm), t.object_name)
                  and t.procedure_name =
                      nvl(upper(p_test_nm), t.procedure_name)
                order by t.object_id, t.subprogram_id) loop
      v_test.nm_pack  := rw.package_nm;
      v_test.nm_test  := rw.test_nm;
      v_test.pr_setup := (rw.setup_nm is not null);
      v_test.pr_down  := (rw.down_nm is not null);
      v_result_test.extend;
      v_result_test(v_result_test.last) := v_test;
    end loop;
    return v_result_test;
  end get_test_info;
  /**
  * ������ �� ���������� ������
  * @param  p_pack_nm  ������������ ������ ��� ������
  * @param  p_test_nm  ������������ ��������� ����� ������ ������ ��� ������
  * @param  p_ignore_success �������� ����������� �������� ��������,
  *         �� ��������� �������� �������� �� ����������
  * @param  p_store_log ������� ���������� ���� � �������
  *         �� ��������� ������� � ������� (dbms_output)
  * ���� ��������� �� ������� �� ����� ����������� ��� �����
  */
  procedure run_test(p_pack_nm        varchar2,
                     p_test_nm        varchar2,
                     p_ignore_success boolean := true,
                     p_store_log      boolean := false) is
    v_test_arr t_test_tbl := get_test_info(p_pack_nm, p_test_nm);
    v_index    pls_integer;
  begin
    g_id_run         := seq_unit_test.nextval;
    g_dt_run         := sysdate;
    g_ignore_success := p_ignore_success;
    g_store_log      := p_store_log;
    v_index          := v_test_arr.first;
    while v_index is not null loop
      g_test := v_test_arr(v_index);
      begin
        if g_test.pr_setup then
          execute immediate 'begin ' || g_test.nm_pack || '.S_' ||
                            substr(g_test.nm_test, 3) || '; end;';
        end if;
        begin
          execute immediate 'begin ' || g_test.nm_pack || '.' ||
                            g_test.nm_test || '; end;';
        exception
          when others then
            -- ���� ���� ����, down  ��� ����� ������ �����������
            fail(sqlerrm);
        end;
        if g_test.pr_down then
          execute immediate 'begin ' || g_test.nm_pack || '.D_' ||
                            substr(g_test.nm_test, 3) || '; end;';
        end if;
      
      exception
        when others then
          fail(sqlerrm);
      end;
      v_index := v_test_arr.next(v_index);
    end loop;
    g_test := null;
  end run_test;

  /**
  * �������� ������������� ���������� ������� ������ � ������ ������ ������
  */
  function get_last_run_id return number is
  begin
    return g_id_run;
  end get_last_run_id;

  procedure fail(p_message in varchar2 default '') is
  begin
    log(c_result_fail, p_message, null);
  end;

  procedure assert_true(p_condition in boolean,
                        p_message   in varchar2 default '') is
  begin
    if p_condition then
      log(c_result_success, null, null);
    else
      log(c_result_fail,
          p_message,
          c_label_expect || ' TRUE ' || c_label_return || ' ' ||
          bool_to_str(p_condition));
    end if;
  end;

  procedure assert_false(p_condition in boolean,
                         p_message   in varchar2 default '') is
  begin
    if not p_condition then
      log(c_result_success, null, null);
    else
      log(c_result_fail,
          p_message,
          c_label_expect || ' FALSE ' || c_label_return || ' ' ||
          bool_to_str(p_condition));
    end if;
  end;

  procedure assert_equals(p_expected in varchar2,
                          p_actual   in varchar2,
                          p_message  in varchar2 default '') is
  begin
    if p_expected = p_actual then
      log(c_result_success, null, null);
    else
      log(c_result_fail,
          p_message,
          c_label_expect || ' ' || p_actual || ' ' || c_label_return || ' ' ||
          p_expected);
    end if;
  end;

  procedure assert_equals(p_expected in boolean,
                          p_actual   in boolean,
                          p_message  in varchar2 default '') is
  begin
    if p_expected = p_actual then
      log(c_result_success, null, null);
    else
      log(c_result_fail,
          p_message,
          c_label_expect || ' ' || bool_to_str(p_actual) || ' ' ||
          c_label_return || ' ' || bool_to_str(p_expected));
    end if;
  end;

  procedure assert_equals(p_expected in date,
                          p_actual   in date,
                          p_message  in varchar2 default '') is
  begin
    if p_expected = p_actual then
      log(c_result_success, null, null);
    else
      log(c_result_fail,
          p_message,
          c_label_expect || ' ' || date_to_str(p_actual) || ' ' ||
          c_label_return || ' ' || date_to_str(p_expected));
    end if;
  end;

  procedure assert_equals(p_expected in number,
                          p_actual   in number,
                          p_message  in varchar2 default '') is
  begin
    if p_expected = p_actual then
      log(c_result_success, null, null);
    else
      log(c_result_fail,
          p_message,
          c_label_expect || ' ' || num_to_str(p_actual) || ' ' ||
          c_label_return || ' ' || num_to_str(p_expected));
    end if;
  end;

  procedure assert_equals(p_expected in number,
                          p_actual   in number,
                          p_range    in number,
                          p_message  in varchar2 default '') is
  begin
    if abs(p_expected - p_actual) <= p_range then
      log(c_result_success, null, null);
    else
      log(c_result_fail,
          p_message,
          c_label_expect || ' ' || num_to_str(p_actual) || '+/- ' ||
          num_to_str(p_range) || ' ' || c_label_return || ' ' ||
          num_to_str(p_expected));
    end if;
  end;

  procedure assert_not_equals(p_expected in varchar2,
                              p_actual   in varchar2,
                              p_message  in varchar2 default '') is
  begin
    if not p_expected = p_actual then
      log(c_result_success, null, null);
    else
      log(c_result_fail,
          p_message,
          c_label_expect || ' ' || p_actual || ' ' || c_label_return || ' ' ||
          p_expected);
    end if;
  end;

  procedure assert_not_equals(p_expected in boolean,
                              p_actual   in boolean,
                              p_message  in varchar2 default '') is
  begin
    if not (p_expected = p_actual) then
      log(c_result_success, null, null);
    else
      log(c_result_fail,
          p_message,
          c_label_expect || ' NOT ' || bool_to_str(p_actual) || ' ' ||
          c_label_return || ' ' || bool_to_str(p_expected));
    end if;
  end;

  procedure assert_not_equals(p_expected in date,
                              p_actual   in date,
                              p_message  in varchar2 default '') is
  begin
    if not (p_expected = p_actual) then
      log(c_result_success, null, null);
    else
      log(c_result_fail,
          p_message,
          c_label_expect || ' NOT ' || date_to_str(p_actual) || ' ' ||
          c_label_return || ' ' || date_to_str(p_expected));
    end if;
  end;

  procedure assert_not_equals(p_expected in number,
                              p_actual   in number,
                              p_message  in varchar2 default '') is
  begin
    if not (p_expected = p_actual) then
      log(c_result_success, null, null);
    else
      log(c_result_fail,
          p_message,
          c_label_expect || ' NOT ' || num_to_str(p_actual) || ' ' ||
          c_label_return || ' ' || num_to_str(p_expected));
    end if;
  end;

  procedure assert_not_equals(p_expected in number,
                              p_actual   in number,
                              p_range    in number,
                              p_message  in varchar2 default '') is
  begin
    if abs(p_expected - p_actual) > p_range then
      log(c_result_success, null, null);
    else
      log(c_result_fail,
          p_message,
          c_label_expect || ' NOT ' || num_to_str(p_actual) || '+/- ' ||
          num_to_str(p_range) || ' ' || c_label_return || ' ' ||
          num_to_str(p_expected));
    end if;
  end;

  procedure assert_null(p_actual  in varchar2,
                        p_message in varchar2 default '') is
  begin
    if p_actual is null then
      log(c_result_success, null, null);
    else
      log(c_result_fail,
          p_message,
          c_label_expect || ' NULL ' || c_label_return || ' ' || p_actual);
    end if;
  end;

  procedure assert_null(p_actual in date, p_message in varchar2 default '') is
  begin
    if p_actual is null then
      log(c_result_success, null, null);
    else
      log(c_result_fail,
          p_message,
          c_label_expect || ' NULL ' || c_label_return || ' ' ||
          date_to_str(p_actual));
    
    end if;
  end;

  procedure assert_null(p_actual  in boolean,
                        p_message in varchar2 default '') is
  begin
    if p_actual is null then
      log(c_result_success, null, null);
    else
      log(c_result_fail,
          p_message,
          c_label_expect || ' NULL ' || c_label_return || ' ' ||
          bool_to_str(p_actual));
    end if;
  end;

  procedure assert_null(p_actual  in number,
                        p_message in varchar2 default '') is
  begin
    if p_actual is null then
      log(c_result_success, null, null);
    else
      log(c_result_fail,
          p_message,
          c_label_expect || ' NULL ' || c_label_return || ' ' ||
          num_to_str(p_actual));
    end if;
  end;

  procedure assert_not_null(p_actual  in varchar2,
                            p_message in varchar2 default '') is
  begin
    if p_actual is not null then
      log(c_result_success, null, null);
    else
      log(c_result_fail,
          p_message,
          c_label_expect || ' NOT NULL ' || c_label_return || ' NULL');
    end if;
  end;

  procedure assert_not_null(p_actual  in boolean,
                            p_message in varchar2 default '') is
  begin
    if p_actual is not null then
      log(c_result_success, null, null);
    else
      log(c_result_fail,
          p_message,
          c_label_expect || ' NOT NULL ' || c_label_return || ' NULL');
    end if;
  end;

  procedure assert_not_null(p_actual  in date,
                            p_message in varchar2 default '') is
  begin
    if p_actual is not null then
      log(c_result_success, null, null);
    else
      log(c_result_fail,
          p_message,
          c_label_expect || ' NOT NULL ' || c_label_return || ' NULL');
    end if;
  end;

  procedure assert_not_null(p_actual  in number,
                            p_message in varchar2 default '') is
  begin
    if p_actual is not null then
      log(c_result_success, null, null);
    else
      log(c_result_fail,
          p_message,
          c_label_expect || ' NOT NULL ' || c_label_return || ' NULL');
    end if;
  end;

end unit_test;
/
