select typeof(Data), Data from (select flexi_get(11, 1001, json('{"properties":{"11":{"map":{"jsonPath": "$.abc"}}}}'),
json('{"abc": "Crudbit rules"}')) as Data);