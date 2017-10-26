var path = require('path');
var webpack = require('webpack');

module.exports = {
    entry: path.join(__dirname, "../js/deps-index.js"),
    output: {
        filename: "build/bin/duk-deps.js"
    },
    resolve: {
        // Add '.ts' and '.tsx' as a resolvable extension.
        extensions: [".ts", ".tsx", ".js"]
    },
    module: {
        loaders: [
            // all files with a '.ts' or '.tsx' extension will be handled by 'ts-loader'
            {test: /\.tsx?$/, loader: "ts-loader"}
        ]
    },
    plugins:
        [
            new webpack.optimize.UglifyJsPlugin(
                {
                    compress: {
                        warnings: false
                    },
                    include: /\.js$/,
                    minimize: true,
                    sourceMap: true,
                    mangle: true,
                    output: {comments: false}
                }
            )
        ]
};