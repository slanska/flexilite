create view if not exists __tests__ as
select 1 as TestName, 1 as ExpectedValue, 1 as ActualValue;

create trigger if not exists __tests__Insert instead of insert
on __tests__
for each Row
begin
    select RAISE(fail, err_msg)
    from (select new.ExpectedValue as ev, new.ActualValue as av,
    printf('%s: expected %s, but actual = %s', new.TestName, new.ExpectedValue, new.ActualValue) as err_msg) s
    where s.ev <> s.av;
end;

--insert into __tests__ select 'Test A', 2, 1;

select typeof(Data), Data from (select flexi_get(11, 1001, json('{"properties":{"11":{"map":{"jsonPath": "$.abc"}}}}'),
json('{"abc": "Crudbit rules"}')) as Data);
select var('CurrentUserID', hex(randomblob(16)));
select var('currentuserid');
select var('current_user_id');
select var('CurrentUserID'), typeof(var('CurrentuserID'));;
select var('CurrentuserID');
select var('CurrentUserID', json('{"aaa":"bbb"}'));
select var('CurrentuserID'), typeof(var('CurrentuserID'));
select json_extract(var('CurrentuserID'),'$.aaa');
select var('CurrentuserID', 43.444);
select var('CurrentuserID'), typeof(var('CurrentuserID'));