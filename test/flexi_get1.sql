select typeof(Data), Data from (select flexi_get(11, 1001, json('{"properties":{"11":{"map":{"jsonPath": "$.abc"}}}}'),
json('{"abc": "Crudbit rules"}')) as Data);
--select var('CurrentUserID', hex(randomblob(16)));
--select var('currentuserid');
--select var('current_user_id');
--select var('CurrentUserID'), typeof(var('CurrentuserID'));;
--select var('CurrentuserID');
--select var('CurrentUserID', json('{"aaa":"bbb"}'));
--select var('CurrentuserID'), typeof(var('CurrentuserID'));
--select json_extract(var('CurrentuserID'),'$.aaa');
--select var('CurrentuserID', 43.444);
select var('CurrentuserID'), typeof(var('CurrentuserID'));