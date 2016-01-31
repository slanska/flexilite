/**
 * Created by slanska on 2016-01-18.
 */

/// <reference path="../../../typings/tsd.d.ts"/>

import Driver = require ('./Driver');
import orm = require("orm");

// Register Flexilite driver
(<any>orm).addAdapter('flexilite', Driver);