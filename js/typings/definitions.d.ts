/**
 * Created by slanska on 2017-01-23.
 */

/*
 This TypeScript definition module contains JSON contracts for Flexilite functions
 */

/*
 Property types
 */
declare type IPropertyType = 'text' | 'integer' | 'number' | 'boolean' | 'date' |
    'timespan' | 'datetime' | 'binary' | 'uuid' | 'enum' | 'reference' | 'any';

declare type PropertyIndexMode = 'none' | 'index' | 'unique' | 'range' | 'fulltext';

declare interface IReferencePropertyDef {
}

declare interface IEnumPropertyDef {

}

declare interface IPropertyDef {
    rules: {
        type: IPropertyType;
        minOccurences?: number;
        maxOccurences?: number;
        regex?: string;
    },
    indexing?: PropertyIndexMode;
    name: string,
    defaultValue?: Object;
    refDef?: IReferencePropertyDef;
    enumDef?: IEnumPropertyDef;
}

declare interface IPropertyRefactorDef extends IPropertyDef {
    $renameTo?: string;
    $drop?: boolean;
}

declare interface IQueryWhereDef {

}

declare interface IQueryOrderByDef {
}

declare interface IQuerySelectDef {
}

declare interface IQueryDef {
    where?: IQueryWhereDef;
    from?: string;
    limit?: number;
    skip?: number;
    select?: IQuerySelectDef;
    orderBy?: IQueryOrderByDef;
    userId?: string;
    culture?: string;
    bookmark?: string;
}

declare type QueryOperator = '$eq' | '$ne' | '$lt' | '$gt' | '$le' | '$ge' | '$in'
    | '$between' | '$exists' | '$like' | '$match' | '$not';