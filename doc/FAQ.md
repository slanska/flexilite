##### Why Flexilite

I had this idea in my mind for several years. Eventually this idea shaped into something practical,
so I decided to devote some free personal time to implement it in real.

##### Why Lua?

Initially this project started as pure C library. All ideas were formulated, so coding looked pretty 
straightforward. Apparently, developing this kind of app in pure C appeared to be tedious, too verbose and error prone.
After having some functionality implemented, I finally formulated what would be the best language/environment
to use for developing such kind of library.

I needed something which would allow:

* easy parsing and stringifying from/to JSON into app structures, as Flexilite uses this a lot

* garbage collector

* easy and efficient access to C/SQLite API

* possible using this language for user defined functions and triggers 

* reasonable size

* developer convenience, like ability to debug and fun to code

* portable - working on wide spectrum of platforms, ideally anywhere where SQLite itself can be used,
but with primarily goal to be used in desktop and web apps.

* reasonable performance
 
I started considering alternatives. I looked at Modern C++, Nim, Go, Rust, Kotlin Native. 
I also checked JavaScript (TypeScript) and Python
as dynamic scripting languages. They both looked pretty promising. Performance is very important, of course.
But for this library, it becomes almost irrelevant, as the library ads little overhead on top of database
activity, performed by SQLite, so having slow interpreter to handle that overhead should not be a roadblock.

My ideal candidate would be JavaScript (TypeScript, to be exact), embedded into library. I have decent
 experience in TypeScript, with all linting and static typing support, so I looked at V8, SpiderMonkey
 and Chakra.
 They seem to be pretty heavy for this library, even though provided very impressive performance. Also, I learned
 that iOS does not allow JITting, so V8 or SpiderMonkey left tournament.
 
 I also checked Duktape - project looks really interesting and promising. I even start coding, and set up project
 with bundling TypeScript files into webpack amalgamation. Idea was to develop mostly in 
 node.js environment and minimize portion of C/C++ development. 
 I faced couple issues almost immediately - debugging, and SQLite API. 
 
 And then I took another look at Lua... With all my previous try-and-fail experience, with all frustration
 and disappointment, I gave Lua second chance. And I was pretty amazed on how good Lua played in all
 aspects listed above.
 
 With Lua, I can develop all business logic in scripting language, debug and make immediate modifications.
 
 Let's see how my requirement were met by Lua:
 
 * easy JSON interaction - 5 of 5, with luacjson library and direct decoding to Lua tables.
 
 * garbage collector - yes
 
 * easy and efficient access to C/SQLite API - with lua.sqlite.org and minor modifications I was able
 to get universal API to be used from within C library as well as when running Lua script directly
 
 * possible using this language for user defined functions and triggers - Yes
 
 * reasonable size - could not be better. Overhead for LuaJIT is 1 MB.
 
 * developer convenience, like ability to debug and fun to code - Yes! I love Lua syntax. Debugging is not so
 good. But I can live with it.
 
 * portable - wherever Lua and SQLite can be used, Flexilite would be able run there, too.

* reasonable performance - standard Lua is pretty fast (comparable to CPython, for instance). 
LuaJIT is really masterpiece, performing an par with compiled languages. I did not check it myself yet, 
but according to multiple benchmarks, LuaJIT 
is in average just 3 times slower than C/C++, which is absolutely amazing for dynamic interpreted language.

##### Why SQLite?

Because SQLite seemed to be ideal candidate for implementing Flexilite concept. It is widely used,
small, fast, feature rich, portable. Flexilite utilizes many SQLite unique features to provide best user experience.
Such features as virtual tables, full text search, clustered and conditional indexes, triggers, dynamic typing,
common table expressions, custom functions, reversed indexes, updatable views and others helped a lot in bringing Flexilite
ideas to practice. 

##### Where can it be used?

Flexilite can be used wherever SQLite can be used. From embedded Linux, mobile and desktop applications,
to small to medium websites, to cloud services with moderate load. You name it. Generally, its niche is for department or small business databases,
with few millions records, few gigabytes of file size, few dozens simultaneous users.

##### Future plans

There are 3 possible directions that Flexilite can grow into.

* Port to a different DB engine, which can handle heavy traffic and provide the same features. 
BerkeleyDB could be the first candidate to consider.

* Implementing full fledged computational abilities. We can expect Flexilite to become alternative to 
large Excel and/or Access databases, with ability to perform calculations and other user defined actions directly
on data, using Lua scripting

* Of course, improve performance, fix bugs, add more features.  