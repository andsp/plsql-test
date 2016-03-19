create or replace package fixture_helper is

  /**
  * Пакет используется для хранения ключей при создании фикстур
  */

  c_varchar constant number := 1;

  c_date constant number := 2;

  c_number constant number := 3;

  /**
  * Сохранить в сессии значение, ключем является имя
  */

  procedure set(p_name varchar2, p_value varchar2);

  procedure set_date(p_name varchar2, p_value date);

  procedure set_number(p_name varchar2, p_value number);

  /**
  * Получить значение сохранненное ранее, в случае отсутствия вернется null
  */
  function get(p_name varchar2) return varchar2;

  function get_date(p_name varchar2) return date;

  function get_number(p_name varchar2) return number;

  /**
  * Стереть значение по имени
  * @param p_name        имя параметра
  * @param p_data_type   тип параметра который надо очистить (в зависимости от того какого типа заполнение было использовано)
  *                      1 строковый
  *                      2 дату
  *                      3 число
  *                      по умолчанию null  - удалит параметры всех типов данных с указанным именем
  */
  procedure clear(p_name varchar2, p_data_type number := null);

  /**
  * Удаляем все параметры всех типов
  */
  procedure clear_all;

end fixture_helper;
/
create or replace package body fixture_helper is

  type t_container is table of varchar2(32000) index by varchar2(4000);

  type t_date_container is table of date index by varchar2(4000);

  type t_number_container is table of number index by varchar2(4000);

  g_container t_container;

  g_date_container t_date_container;

  g_number_container t_number_container;

  procedure set(p_name varchar2, p_value varchar2) is
  begin
    g_container(p_name) := p_value;
  end set;

  procedure set_date(p_name varchar2, p_value date) is
  begin
    g_date_container(p_name) := p_value;
  end set_date;

  procedure set_number(p_name varchar2, p_value number) is
  begin
    g_number_container(p_name) := p_value;
  end set_number;

  function get(p_name varchar2) return varchar2 is
  begin
    if g_container.exists(p_name) then
      return null;
    else
      return g_container(p_name);
    end if;
  end get;

  function get_date(p_name varchar2) return date is
  begin
    if g_date_container.exists(p_name) then
      return null;
    else
      return g_date_container(p_name);
    end if;
  end get_date;

  function get_number(p_name varchar2) return number is
  begin
    if g_number_container.exists(p_name) then
      return null;
    else
      return g_number_container(p_name);
    end if;
  end get_number;

  procedure clear(p_name varchar2, p_data_type number := null) is
  begin
    case p_data_type
      when c_varchar then
        g_container.delete(p_name);
      when c_date then
        g_date_container.delete(p_name);
      when c_number then
        g_number_container.delete(p_name);
      else
        if p_data_type is null then
          clear(p_name, c_varchar);
          clear(p_name, c_date);
          clear(p_name, c_number);
        end if;
    end case;
  end clear;

  procedure clear_all is
  begin
    g_container.delete;
    g_date_container.delete;
    g_number_container.delete;
  end clear_all;

end fixture_helper;
/
