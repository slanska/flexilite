flexi_class_create(className:string, classDef: IClassDef)

flexi_class_alter(className:string, classDef: IClassDef)

flexi_class_drop(className:string)

flexi_prop_create(className:string, propName:string, propDef:IPropDef)

###### flexi_prop_alter(className:string, propName:string, propDef:IPropDef)

flexi_prop_drop(className:string, propName:string)

###### flexi_query(queryOptions:IQueryOptions)
###### flexi_query(className:string, filter:IQueryFilter, orderBy?:IQueryOrderBy)
from:string
where:IQueryFilter
orderBy:IQueryOrderBy
select
skip
limit


###### flexi_query_multi(queryOptions:IQueryOptions[]):IQueryResult


###### flexi_save(data:IQueryResult.data)

flexi_struct_merge(options: IStructMergeOptions)
flexi_struct_split(options:IStructSplitOptions)

flexi_prop_split()
flexi_prop_merge()

flexi_enum_create()
flexi_enum_alter()
flexi_enum_drop()

flexi_remove_dups()



