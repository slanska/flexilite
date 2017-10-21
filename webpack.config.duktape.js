/**
 * Created by slanska on 2017-02-11.
 */

var path = require('path');

module.exports = {
    // TODO Temp- Use duk
    entry: "./js/flexish/index.ts",
    output: {
        filename: "./js/__build/flexi-duk.js"
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
                // path.resolve(__dirname, "node_modules/lodash")
            ]
            }
        ]
    }
};