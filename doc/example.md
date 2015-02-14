# Пример написания теста

Пусть у нас есть пакет который надо протестировать.

```plsql
create or replace package pckg_nds is

  function get_nds(p_sm number,p_pr_inside boolean) return number;

end pckg_nds;
/
create or replace package body pckg_nds is

  function get_nds(p_sm number,p_pr_inside boolean) return number is
    v_nds number;
  begin
    if p_pr_inside then
      v_nds :=  (p_sm * 18)/(100+18);
    else
      v_nds :=  (p_sm * 18)/100;
    end if;
    return v_nds;
  end get_nds;
  
end pckg_nds;
/
```

Для теста мы создадим тестовый пакет (можно конечно в уже готовый, если он есть) с тестовой процедурой, 
в которой вызываем методы assert  для логирования результата выполнения.

```plsql
create or replace package t_nds is

  procedure t_get_sm;

end t_nds;
/
create or replace package body t_nds is

  procedure t_get_sm is
  begin
    unit_test.assert_equals(pckg_nds.get_nds(118,true),18);
    unit_test.assert_equals(pckg_nds.get_nds(100,false),18);
  end;
  
end t_nds;
/
```
Конечно, в большинстве случаев функционал намного сложнее и связан с состоянием данных. 
Для этого в тестовом методе или в процедуре setup для теста вы можете подготавливать тестовую ситуацию, 
а в методе teardown откатывать эти изменения.
