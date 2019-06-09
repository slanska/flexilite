-- Uncomment following line if running in the context when Flexilite is not yet loaded
-- select load_extension('libFlexilite');

select flexi('configure');

select flexi('load', '../test/json/Northwind.db3.schema.json');

create virtual table if not exists [EmployeesTerritories]
                using flexi_rel ([EmployeeID], [TerritoryID], [Employees] hidden, [Territories] hidden);

                