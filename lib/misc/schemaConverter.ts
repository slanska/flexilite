/**
 * Created by slanska on 2016-03-26.
 */

///<reference path="../models/definitions.d.ts"/>
/// <reference path="../../typings/node/node.d.ts"/>
/// <reference path="../../node_modules/orm/lib/TypeScript/orm.d.ts" />
/// <reference path="../../typings/tsd.d.ts" />

'use strict';

import sqlite3 = require('sqlite3');
var Sync = require('syncho');
import _ = require('lodash');
import orm = require('orm');

/*
 Converts node-orm2 schema definition as it is passed to sync method,
 to Flexilite format
 */
module Flexilite
{
    export class SchemaConverter
    {
        constructor(private db:sqlite3.Database, public sourceSchema:ISyncOptions)
        {
        }

        private _targetSchema = {} as ISchemaDefinition;

        public get targetSchema()
        {
            return this._targetSchema
        };

        private _targetCollectionSchema = {} as ICollectionSchemaRules;

        public get targetCollectionShema()
        {
            return this._targetCollectionSchema;
        }

        public getNameID:(name:string)=>number;

        public static nodeOrmTypeToFlexiliteType(ormType:string):PROPERTY_TYPE
        {
            var result:string;
            switch (ormType.toLowerCase())
            {
                case 'serial':
                case 'integer':
                    return PROPERTY_TYPE.integer;

                case 'number':
                    return PROPERTY_TYPE.number;

                case'binary':
                    return PROPERTY_TYPE.binary;

                case 'text':
                    return PROPERTY_TYPE.text;

                case 'boolean':
                    return PROPERTY_TYPE.boolean;

                case 'object':
                    return PROPERTY_TYPE.reference;

                case 'date':
                    return PROPERTY_TYPE.date;

                case 'enum':
                    return PROPERTY_TYPE.ENUM;

                default:
                    throw new Error(`Not supported property type: ${ormType}`);
            }
        }

        // Expects to be running inside of Syncho call
        public convert()
        {
            if (!_.isFunction(this.getNameID))
                throw new Error('getNameID() is not assigned');

            this._targetCollectionSchema = {properties: {}} as ICollectionSchemaRules;
            this._targetSchema = {properties: {}} as ISchemaDefinition;

            var s = this._targetSchema;
            var c = this._targetCollectionSchema;

            _.forEach(this.sourceSchema.allProperties, (item:INodeORMPropertyDef, propName:string) =>
            {
                let propID = this.getNameID(propName);
                let sProp = item.ext || {} as ISchemaPropertyDefinition;
                sProp.rules = sProp.rules || {} as IPropertyRulesSettings;
                sProp.map = sProp.map || {} as IPropertyMapSettings;
                sProp.ui = sProp.ui || {} as IPropertyUISettings;

                let cProp = {} as ICollectionSchemaProperty;

                switch (item.klass)
                {
                    case 'primary':
                        sProp.rules.type = SchemaConverter.nodeOrmTypeToFlexiliteType(item.type);
                        if (item.size)
                            sProp.rules.maxLength = item.size;

                        if (item.defaultValue)
                            cProp.defaultValue = item.defaultValue;

                        if (item.unique || item.indexed)
                        {
                            cProp.unique = item.unique;
                            cProp.indexed = true;
                        }

                        if (item.mapsTo && !_.isEqual(item.mapsTo, propName))
                            cProp.columnNameID = this.getNameID(item.mapsTo);

                        // TODO item.big
                        // TODO item.time

                        s.properties[propID] = sProp;
                        c.properties[propID] = cProp;

                        break;

                    case 'hasOne':
                        // Generate relation
                        sProp.rules.type = PROPERTY_TYPE.reference;
                        //this.sourceSchema.one_associations[propName].
                        //sProp.referenceTo =
                        break;

                    case 'hasMany':
                        // Generate relation
                        break;
                }
            });
        }
    }
}

export = Flexilite.SchemaConverter;