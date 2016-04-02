/**
 * Created by slanska on 2016-03-26.
 */

///<reference path="../def/definitions.d.ts"/>
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
    export class SchemaHelper
    {
        constructor(private db:sqlite3.Database, public sourceSchema:ISyncOptions)
        {
        }

        private _targetSchema = {} as ISchemaDefinition;

        public get targetSchema()
        {
            return this._targetSchema
        };

        private _targetClass = {} as IClassDefinition;

        public get targetClass()
        {
            return this._targetClass;
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

            this._targetClass = {properties: {}} as IClassDefinition;
            this._targetSchema = {properties: {}} as ISchemaDefinition;

            var s = this._targetSchema;
            var c = this._targetClass;

            _.forEach(this.sourceSchema.allProperties, (item:IORMPropertyDef, propName:string) =>
            {
                let propID = this.getNameID(propName);
                let sProp = item.ext || {} as ISchemaPropertyDefinition;
                let cProp = {} as IClassProperty;
                cProp.rules = cProp.rules || {} as IPropertyRulesSettings;
                cProp.map = cProp.map || {} as IPropertyMapSettings;
                cProp.ui = cProp.ui || {} as IPropertyUISettings;


                switch (item.klass)
                {
                    case 'primary':
                        cProp.rules.type = SchemaHelper.nodeOrmTypeToFlexiliteType(item.type);
                        if (item.size)
                            cProp.rules.maxLength = item.size;

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

export = Flexilite.SchemaHelper;