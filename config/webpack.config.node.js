/**
 * Created by slanska on 2017-02-11.
 */

/*
Webpack configuration to prepare JS bundle for Flexlite sources to run
in node JS environment
 */

var path = require('path');

module.exports = {
    // TODO Temp- In future se duk
    entry: "./js/duk/index.js",
    output: {
        filename: "build/bin/flexi-duk.js"
    },
    resolve: {
        // Add '.ts' and '.tsx' as a resolvable extension.
        extensions: [".webpack.js", ".web.js", ".ts", ".tsx", ".js"]
    },
    module: {
        loaders: [
            // all files with a '.ts' or '.tsx' extension will be handled by 'ts-loader'
            {
                test: [/\.tsx?$/, /\.jsx?$/], loader: "ts-loader", include: [
                path.resolve(__dirname, "js"),
            ]
            }
        ]
    },
    externals: {
        lodash: 'lodash',
        moment: 'moment'
    }
};