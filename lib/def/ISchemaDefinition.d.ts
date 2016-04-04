/**
 * Created by slanska on 2016-03-27.
 */


/// <reference path="../../typings/lib.d.ts"/>

/*
 Definitions for .schemas Data JSON column
 */

interface IPropertyMapSettings
{
    /*
     path to access property value
     Example: given payload {firstName: 'John', lastName: 'Smith', address: {line1: '123 Main Street', city: 'Someville'}, children: [123, 345]}
     '.firstName' -> will return 'John'
     '.address.city' -> 'Someville'
     '.children[0]' -> 123

     Payload may be array (e.g. [0, 3, {attr1: 'AAA'}, 5]). In this case jsonPath will look like:
     [0] or [2].attr1
     Note: missing dot at the beginning of specification.

     For boxed objects json paths will be concatenated on-fly
     For OBJECT property for boxed object, json path may be empty string. In this case, attributes of boxed objects are
     placed on the same level of hierarchy as attributes of master object (we can say that master object is extended with boxed object)

     Value referenced by jsonPath can be scalar or vector, regardless of how property's maxOccurences is defined. Flexilite
     will handle this gracefully, so when scalar value is expected in accordance with property definition, but actual value is
     array, first item in this array will be returned. Opposite, if property is defined as vector, but actual value is scalar,
     it will be converted to array of one element
     */
    jsonPath:string;

    /*
     For boolean properties, defined as items in array. For example:
     ['BoolProp1', 'BoolProp2', 'BoolProp3']. Presence of item in array means `true`, absence means 'false', respectively.
     */
    arrayItemValue?:string;

    /*
     For boolean properties, defined as bit mask. If value & bitMask == bitMask -> true, otherwise -> false
     */
    andBitMask?:number;
}

interface ISchemaPropertyDefinition
{
    map:IPropertyMapSettings;
}

/*
 Structure of Data fields in .schemas table
 */
interface ISchemaDefinition
{
    properties:{[propertyID:number]:ISchemaPropertyDefinition};
}

type ISchemaPropertyDictionary = {[propName:string]: ISchemaPropertyDefinition};




