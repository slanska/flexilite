select flexi_get(11, json('{"properties":{"11":{"map":{"jsonPath": "$.abc"}}}}'),
json('{"abc": "Some text"}'));