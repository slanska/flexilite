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
 Converts node-orm2 schema definition to Flexilite format
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

            var t = this._targetSchema;
            t.properties = {};
            _.forEach(this.sourceSchema.allProperties, (item:INodeORMPropertyDef, propName:string) =>
            {
                let propID = this.getNameID(propName);
                let prop = item.ext || {} as ISchemaPropertyDefinition;
                prop.rules = prop.rules || {} as IPropertyRulesSettings;
                prop.map = prop.map || {} as IPropertyMapSettings;
                prop.ui = prop.ui || {} as IPropertyUISettings;

                switch (item.klass)
                {
                    case 'primary':
                        prop.rules.type = SchemaConverter.nodeOrmTypeToFlexiliteType(item.type);
                        if (item.size)
                            prop.rules.maxLength = item.size;

                        t.properties[propID] = prop;

                        break;
                    case 'hasOne':
                        break;

                    case 'hasMany':
                        break;
                }
            });
        }
    }
}

export = Flexilite.SchemaConverter;