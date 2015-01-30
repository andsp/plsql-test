create or replace package unit_test is

  /**
  * cтруктура теста
  */
  type t_test_info is record(
    nm_pack  varchar2(50),
    nm_test  varchar2(50),
    pr_setup boolean,
    pr_down  boolean);
  /**
  * массив тестов
  */
  type t_test_tbl is table of t_test_info;
  /**
  * запуск тестов
  * @param  p_pack_nm  наименование пакета для поиска
  * @param  p_test_nm  наименование процедуры теста внутри пакеета для поиска
  * если параметры не указаны то будут выполняться все тесты
  */
  procedure run_test(p_pack_nm varchar2, p_test_nm varchar2);

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
create or replace package body unit_test is

  RESULT_SUCCESS constant number := 1;

  RESULT_FAIL constant number := 0;

  LABEL_EXPECT constant varchar2(50) := 'ожидали';

  LABEL_RETURN constant varchar2(50) := 'получили';

  /**
  * идентификатор запуска
  */
  g_id_run number;
  /**
  * время старта запуска
  */
  g_dt_run date;
  /**
  * текущий тест
  */
  g_test t_test_info;

  /**
  * запись результата в лог
  * @param p_result  код результата
  * @param p_message сообщение теста
  * @param p_addition дополнительная информация
  */
  procedure log(p_result number, p_message varchar2, p_addition varchar2) is
    pragma autonomous_transaction;
  begin
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
  * получить список тестов на схеме
  * @param  p_pack_nm  наименование пакета для поиска
  * @param  p_test_nm  наименование процедуры теста внутри пакеета для поиска
  * @return  массив тестов ограниченных параметрами, если передать все параметры пустимы то вернет полный список тестов со схемы
  */
  function get_test_info(p_pack_nm varchar2, p_test_nm varchar2)
    return t_test_tbl is
    v_result_test t_test_tbl := t_test_tbl();
    v_test        t_test_info;
  begin
    for rw in (select t.object_name    as package_nm,
                      t.PROCEDURE_NAME as test_nm,
                      s.PROCEDURE_NAME as setup_nm,
                      d.PROCEDURE_NAME as down_nm
                 from user_procedures t
                 left join user_procedures s
                   on s.object_name = t.object_name
                  and s.PROCEDURE_NAME = 'SETUP_' || t.PROCEDURE_NAME
                 left join user_procedures D
                   on D.object_name = t.object_name
                  and d.PROCEDURE_NAME = 'DOWN_' || t.PROCEDURE_NAME
                where t.object_type = 'PACKAGE'
                  and substr(t.object_name, 1, 2) = 'T_'
                  and substr(t.PROCEDURE_NAME, 1, 2) = 'T_'
                  and t.object_name = nvl(upper(p_pack_nm), t.object_name)
                  and t.PROCEDURE_NAME =
                      nvl(upper(p_test_nm), t.PROCEDURE_NAME)
                order by t.object_id, t.SUBPROGRAM_ID) loop
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
  * запуск на выполнение массива тестов
  * @param  p_pack_nm  наименование пакета для поиска
  * @param  p_test_nm  наименование процедуры теста внутри пакеета для поиска
  * если параметры не указаны то будут выполняться все тесты
  */
  procedure run_test(p_pack_nm varchar2, p_test_nm varchar2) is
    v_test_arr t_test_tbl := get_test_info(p_pack_nm, p_test_nm);
    v_index    pls_integer;
  begin
    g_id_run := SEQ_UNIT_TEST.Nextval;
    g_dt_run := sysdate;
    v_index  := v_test_arr.first;
    while v_index is not null loop
      g_test := v_test_arr(v_index);
      begin
        if g_test.pr_setup then
          execute immediate 'begin ' || g_test.nm_pack || '.SETUP_' ||
                            g_test.nm_test || '; end;';
        end if;
        execute immediate 'begin ' || g_test.nm_pack || '.' ||
                          g_test.nm_test || '; end;';
        if g_test.pr_down then
          execute immediate 'begin ' || g_test.nm_pack || '.DOWN_' ||
                            g_test.nm_test || '; end;';
        end if;
      exception
        when others then
          fail(sqlerrm);
      end;
      v_index := v_test_arr.next(v_index);
    end loop;
    g_id_run := null;
  end run_test;

  procedure fail(p_message in varchar2 default '') is
  begin
    log(RESULT_FAIL, p_message, null);
  end;

  procedure assert_true(p_condition in boolean,
                        p_message   in varchar2 default '') is
  begin
    if p_condition then
      log(RESULT_SUCCESS, null, null);
    else
      log(RESULT_FAIL,
          p_message,
          LABEL_EXPECT || ' TRUE ' || LABEL_RETURN || ' ' ||
          bool_to_str(p_condition));
    end if;
  end;

  procedure assert_false(p_condition in boolean,
                         p_message   in varchar2 default '') is
  begin
    if not p_condition then
      log(RESULT_SUCCESS, null, null);
    else
      log(RESULT_FAIL,
          p_message,
          LABEL_EXPECT || ' FALSE ' || LABEL_RETURN || ' ' ||
          bool_to_str(p_condition));
    end if;
  end;

  procedure assert_equals(p_expected in varchar2,
                          p_actual   in varchar2,
                          p_message  in varchar2 default '') is
  begin
    if p_expected = p_actual then
      log(RESULT_SUCCESS, null, null);
    else
      log(RESULT_FAIL,
          p_message,
          LABEL_EXPECT || ' ' || p_actual || ' ' || LABEL_RETURN || ' ' ||
          p_expected);
    end if;
  end;

  procedure assert_equals(p_expected in boolean,
                          p_actual   in boolean,
                          p_message  in varchar2 default '') is
  begin
    if p_expected = p_actual then
      log(RESULT_SUCCESS, null, null);
    else
      log(RESULT_FAIL,
          p_message,
          LABEL_EXPECT || ' ' || bool_to_str(p_actual) || ' ' ||
          LABEL_RETURN || ' ' || bool_to_str(p_expected));
    end if;
  end;

  procedure assert_equals(p_expected in date,
                          p_actual   in date,
                          p_message  in varchar2 default '') is
  begin
    if p_expected = p_actual then
      log(RESULT_SUCCESS, null, null);
    else
      log(RESULT_FAIL,
          p_message,
          LABEL_EXPECT || ' ' || date_to_str(p_actual) || ' ' ||
          LABEL_RETURN || ' ' || date_to_str(p_expected));
    end if;
  end;

  procedure assert_equals(p_expected in number,
                          p_actual   in number,
                          p_message  in varchar2 default '') is
  begin
    if p_expected = p_actual then
      log(RESULT_SUCCESS, null, null);
    else
      log(RESULT_FAIL,
          p_message,
          LABEL_EXPECT || ' ' || num_to_str(p_actual) || ' ' ||
          LABEL_RETURN || ' ' || num_to_str(p_expected));
    end if;
  end;

  procedure assert_equals(p_expected in number,
                          p_actual   in number,
                          p_range    in number,
                          p_message  in varchar2 default '') is
  begin
    if abs(p_expected - p_actual) <= p_range then
      log(RESULT_SUCCESS, null, null);
    else
      log(RESULT_FAIL,
          p_message,
          LABEL_EXPECT || ' ' || num_to_str(p_actual) || '+/- ' ||
          num_to_str(p_range) || ' ' || LABEL_RETURN || ' ' ||
          num_to_str(p_expected));
    end if;
  end;

  procedure assert_not_equals(p_expected in varchar2,
                              p_actual   in varchar2,
                              p_message  in varchar2 default '') is
  begin
    if not p_expected = p_actual then
      log(RESULT_SUCCESS, null, null);
    else
      log(RESULT_FAIL,
          p_message,
          LABEL_EXPECT || ' ' || p_actual || ' ' || LABEL_RETURN || ' ' ||
          p_expected);
    end if;
  end;

  procedure assert_not_equals(p_expected in boolean,
                              p_actual   in boolean,
                              p_message  in varchar2 default '') is
  begin
    if not (p_expected = p_actual) then
      log(RESULT_SUCCESS, null, null);
    else
      log(RESULT_FAIL,
          p_message,
          LABEL_EXPECT || ' NOT ' || bool_to_str(p_actual) || ' ' ||
          LABEL_RETURN || ' ' || bool_to_str(p_expected));
    end if;
  end;

  procedure assert_not_equals(p_expected in date,
                              p_actual   in date,
                              p_message  in varchar2 default '') is
  begin
    if not (p_expected = p_actual) then
      log(RESULT_SUCCESS, null, null);
    else
      log(RESULT_FAIL,
          p_message,
          LABEL_EXPECT || ' NOT ' || date_to_str(p_actual) || ' ' ||
          LABEL_RETURN || ' ' || date_to_str(p_expected));
    end if;
  end;

  procedure assert_not_equals(p_expected in number,
                              p_actual   in number,
                              p_message  in varchar2 default '') is
  begin
    if not (p_expected = p_actual) then
      log(RESULT_SUCCESS, null, null);
    else
      log(RESULT_FAIL,
          p_message,
          LABEL_EXPECT || ' NOT ' || num_to_str(p_actual) || ' ' ||
          LABEL_RETURN || ' ' || num_to_str(p_expected));
    end if;
  end;

  procedure assert_not_equals(p_expected in number,
                              p_actual   in number,
                              p_range    in number,
                              p_message  in varchar2 default '') is
  begin
    if abs(p_expected - p_actual) > p_range then
      log(RESULT_SUCCESS, null, null);
    else
      log(RESULT_FAIL,
          p_message,
          LABEL_EXPECT || ' NOT ' || num_to_str(p_actual) || '+/- ' ||
          num_to_str(p_range) || ' ' || LABEL_RETURN || ' ' ||
          num_to_str(p_expected));
    end if;
  end;

  procedure assert_null(p_actual  in varchar2,
                        p_message in varchar2 default '') is
  begin
    if p_actual is null then
      log(RESULT_SUCCESS, null, null);
    else
      log(RESULT_FAIL,
          p_message,
          LABEL_EXPECT || ' NULL ' || LABEL_RETURN || ' ' || p_actual);
    end if;
  end;

  procedure assert_null(p_actual in date, p_message in varchar2 default '') is
  begin
    if p_actual is null then
      log(RESULT_SUCCESS, null, null);
    else
      log(RESULT_FAIL,
          p_message,
          LABEL_EXPECT || ' NULL ' || LABEL_RETURN || ' ' ||
          date_to_str(p_actual));

    end if;
  end;

  procedure assert_null(p_actual  in boolean,
                        p_message in varchar2 default '') is
  begin
    if p_actual is null then
      log(RESULT_SUCCESS, null, null);
    else
      log(RESULT_FAIL,
          p_message,
          LABEL_EXPECT || ' NULL ' || LABEL_RETURN || ' ' ||
          bool_to_str(p_actual));
    end if;
  end;

  procedure assert_null(p_actual  in number,
                        p_message in varchar2 default '') is
  begin
    if p_actual is null then
      log(RESULT_SUCCESS, null, null);
    else
      log(RESULT_FAIL,
          p_message,
          LABEL_EXPECT || ' NULL ' || LABEL_RETURN || ' ' ||
          num_to_str(p_actual));
    end if;
  end;

  procedure assert_not_null(p_actual  in varchar2,
                            p_message in varchar2 default '') is
  begin
    if p_actual is not null then
      log(RESULT_SUCCESS, null, null);
    else
      log(RESULT_FAIL,
          p_message,
          LABEL_EXPECT || ' NOT NULL ' || LABEL_RETURN || ' NULL');
    end if;
  end;

  procedure assert_not_null(p_actual  in boolean,
                            p_message in varchar2 default '') is
  begin
    if p_actual is not null then
      log(RESULT_SUCCESS, null, null);
    else
      log(RESULT_FAIL,
          p_message,
          LABEL_EXPECT || ' NOT NULL ' || LABEL_RETURN || ' NULL');
    end if;
  end;

  procedure assert_not_null(p_actual  in date,
                            p_message in varchar2 default '') is
  begin
    if p_actual is not null then
      log(RESULT_SUCCESS, null, null);
    else
      log(RESULT_FAIL,
          p_message,
          LABEL_EXPECT || ' NOT NULL ' || LABEL_RETURN || ' NULL');
    end if;
  end;

  procedure assert_not_null(p_actual  in number,
                            p_message in varchar2 default '') is
  begin
    if p_actual is not null then
      log(RESULT_SUCCESS, null, null);
    else
      log(RESULT_FAIL,
          p_message,
          LABEL_EXPECT || ' NOT NULL ' || LABEL_RETURN || ' NULL');
    end if;
  end;

end unit_test;
/
