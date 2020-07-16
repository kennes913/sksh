---
title: "on and off python logging"
date: 2020-06-30
publishdate: 2020-07-16
layout: post
categories: ["post"]
---
Recently I was tasked with refactoring the logging for one of our python microservices. This gave me an opportunity to become a little more familiar with the `logging` module. The python logger is flexible and through a simple example, I want to illustrate this while also playing around with some of the `logging` module features.

Say I have a directory structure like so:

{{< highlight bash >}}
    .
    ├── pkg
    │   ├── bar.py
    │   ├── baz.py
    │   ├── config.py
    │   └── foo.py
    └── set_loggers.py

{{< /highlight >}}

In the 3 modules, `pkg.foo`, `pkg.bar` and `pkg.baz`, to keep it simple, the code is the same:

{{< highlight python >}}
import logging

import logging.config

from pkg import config

logging.config.dictConfig(config.configuration.get("logging"))
logger = logging.getLogger(__name__)

def run_statements():
    logger.info("This is an INFO statement.")
    logger.debug("This is a DEBUG statement.")

{{< /highlight >}}

And in `pkg.config`, there's a dictionary that serves as a central logging configuration (we'll explain this later):

{{< highlight python >}}
# config.py
configuration = {
    "logging": {
        "version": 1,
        "formatters": {
            "lib": {
                "class": "logging.Formatter",
                "datefmt": "%Y-%m-%d %H:%M:%S",
                "format": "%(asctime)s.%(msecs)03d | %(levelname)s | %(name)s: %(message)s",
            },
        },
        "handlers": {
            "stdout": {
                "class": "logging.StreamHandler",
                "level": 0,
                "formatter": "lib",
                "stream": "ext://sys.stdout",
            },
            "null": {
                "class": "logging.NullHandler",
                "level": 0,
                "formatter": "lib"
            },
        },
        "loggers": {
            "pkg.foo": {"handlers": ["null"], "level": "INFO"},
            "pkg.bar": {"handlers": ["null"], "level": "INFO"},
            "pkg.baz": {"handlers": ["null"], "level": "INFO"}
        },
    }
}

{{< /highlight >}}

With some knowledge of the `logging` internals and some helper functions, you can import and activate/deactivate logging during runtime:

{{< highlight python >}}
# set_loggers.py
import logging
import sys
import typing

from pkg import foo, bar, baz, config

def stream_to_stdout(loggers: typing.List) -> None:
    """Activate logging for a module or a set of modules."""
    for logger in loggers:
        l = logging.root.manager.loggerDict.get(logger)
        h = logging.StreamHandler(sys.stdout)
        fmt = config.configuration.get("logging").get("formatters").get("lib")
        h.setFormatter(
            logging.Formatter(fmt=fmt.get("format"), datefmt=fmt.get("datefmt"))
        )
        l.handlers.append(h)


def deactivate_stream_log(loggers: typing.List) -> None:
    """Deactivate logging for a module or a set of modules."""
    for logger in loggers:
        l = logging.root.manager.loggerDict.get(logger)
        for i, handler in enumerate(t.handlers):
            if not isinstance(handler, logging.NullHandler):
                l.handlers.pop(i)

# Nothing should output here

for m in  (foo, bar, baz):
    m.run_statements()

# activate some logging
stream_to_stdout(["pkg.bar", "pkg.baz"])

# bar and baz modules will output
for m in  (foo, bar, baz):
    m.run_statements()

stream_to_stdout(["pkg.foo"])

# foo, bar and baz modules will output
for m in  (foo, bar, baz):
    m.run_statements()

deactivate_stream_log(["pkg.foo", "pkg.bar", "pkg.baz"])

# None will output
for m in  (foo, bar, baz):
    m.run_statements()
{{< /highlight >}}

Here's the output from running the above script:

{{< highlight python >}}
Python 3.7.5 (default, Nov 13 2019, 22:50:53)
Type 'copyright', 'credits' or 'license' for more information
IPython 7.9.0 -- An enhanced Interactive Python. Type '?' for help.
2020-07-15 21:50:24.463 | INFO | pkg.bar: This is an INFO statement.
2020-07-15 21:50:24.464 | INFO | pkg.baz: This is an INFO statement.
2020-07-15 21:50:24.464 | INFO | pkg.foo: This is an INFO statement.
2020-07-15 21:50:24.464 | INFO | pkg.bar: This is an INFO statement.
2020-07-15 21:50:24.464 | INFO | pkg.baz: This is an INFO statement.
{{< /highlight >}}

All of the messages are formatted according to the central configurations `"lib"` logging formatter and what was output were only the `INFO` level messages. After activating `pkg.bar` and `pkg.baz`'s loggers, only their messages we're output and following that, `pkg.foo`'s logger was activated so all 3 loggers eventually output statements. I then "deactivated" all of them and the logging went silent.

What's going on here is that I'm selectively choosing what module's logger I want to see messages from at some given point in execution. Why is this useful? Because it allows the developer to choose what modules they want to debug with finer-grained control. Often packages will contain a lot of modules, so that when you run `getLogger("some.module")`, you're often getting only a single module's logging which can sometimes be noisy and unhelpful depending on the implementation. The pattern above allows you to tune into the statements that matter to you during runtime debugging/inspection.

We're able to do this by mutating the handlers attribute on specific loggers within the hierarchy of loggers stored in the `logging.root.manager` object. This object is responsible for building the logging hierarchy and holds all of the loggers that have been initialized during the runtime of your program. By accessing the `manager.loggerDict`, I can build different types of handlers -- in this case a `logging.StreamHandler` -- and append and pop this from the list of handlers attached to specific loggers. Here's what that object looks like in this script:

{{< highlight python >}}
In [1]: logging.root.manager.loggerDict
Out[1]:
{..., # other loggers ommitted
 'pkg.foo': <Logger pkg.foo (INFO)>,
 'pkg': <logging.PlaceHolder at 0x10f20e110>,
 'pkg.bar': <Logger pkg.bar (INFO)>,
 'pkg.baz': <Logger pkg.baz (INFO)>}
{{< /highlight >}}

See the attached handlers in our `pkg.foo`, `pkg.bar`, `pkg.baz` loggers before and after modifying:

{{< highlight python >}}
In [4]: for k,v in logging.root.manager.loggerDict.items():
   ...:     if isinstance(v, logging.Logger):
   ...:         print(k, v.handlers)
...
pkg.foo [<NullHandler (NOTSET)>]
pkg.bar [<NullHandler (NOTSET)>]
pkg.baz [<NullHandler (NOTSET)>]
In [5]: stream_to_stdout(["pkg.bar", "pkg.baz"]) # add handlers
In [6]: for k,v in logging.root.manager.loggerDict.items():
   ...:     if isinstance(v, logging.Logger):
   ...:         print(k, v.handlers)
...
pkg.foo [<NullHandler (NOTSET)>]
pkg.bar [<NullHandler (NOTSET)>, <StreamHandler <stdout> (NOTSET)>]
pkg.baz [<NullHandler (NOTSET)>, <StreamHandler <stdout> (NOTSET)>]
{{< /highlight >}}

I mentioned I'd talk about the central logging configuration. There's plenty of documentation on this, but at a high level, this configuration builds relationships between logging formatters, handlers and behavior. Our configuration is loaded into each module's logger and when the logging hierarchy is built, `logging.root.manager` uses this configuration to instantiate`logging.Logger` objects with some of these settings.

That's why the messages are formatted a specific way and are at a specific `INFO` log level. If we were to set the message level to `DEBUG`, you would see both `INFO` and `DEBUG` statements:

{{< highlight python >}}
Python 3.7.5 (default, Nov 13 2019, 22:50:53)
Type 'copyright', 'credits' or 'license' for more information
IPython 7.9.0 -- An enhanced Interactive Python. Type '?' for help.
2020-07-16 16:13:45.854 | INFO | pkg.bar: This is an INFO statement.
2020-07-16 16:13:45.854 | DEBUG | pkg.bar: This is a DEBUG statement.
2020-07-16 16:13:45.854 | INFO | pkg.baz: This is an INFO statement.
2020-07-16 16:13:45.854 | DEBUG | pkg.baz: This is a DEBUG statement.
2020-07-16 16:13:45.854 | INFO | pkg.foo: This is an INFO statement.
2020-07-16 16:13:45.854 | DEBUG | pkg.foo: This is a DEBUG statement.
2020-07-16 16:13:45.854 | INFO | pkg.bar: This is an INFO statement.
2020-07-16 16:13:45.854 | DEBUG | pkg.bar: This is a DEBUG statement.
2020-07-16 16:13:45.854 | INFO | pkg.baz: This is an INFO statement.
2020-07-16 16:13:45.854 | DEBUG | pkg.baz: This is a DEBUG statement.
{{< /highlight >}}

And for a little but of fun -- another way to do this, would be to directly modify the logger level itself via:

{{< highlight python >}}
...
logging.root.manager.loggerDict.get("pkg.foo").setLevel(logging.INFO)
logging.root.manager.loggerDict.get("pkg.bar").setLevel(logging.INFO)
logging.root.manager.loggerDict.get("pkg.baz").setLevel(logging.INFO)
{{< /highlight >}}

So in addtion to your on and off switch, you can browse channels (kinda) when you're module's logging is activated.

Before ending the post, I want to talk briefly about how the messages arrive to your terminal. This happens through `logging.Handler` objects. In general, a `logging.Handler` object is responsible for taking a `LogRecord` object (the message), filtering and outputting it.
As I mentioned earlier, I added a `logging.StreamHandler` object to each module logger and this handler is responsible for logging the messages to standard out.

At a high level, when a logger `.log()`s a message, each of the handlers' `.handle()` method is called ([source code here](https://github.com/python/cpython/blob/master/Lib/logging/__init__.py#L1651-#L1679)) and eventually our `logging.StreamHandler` is called outputting the message into our terminal for that specific module.

There's a lot more to the logging library that's beyond scope of this post, but in general, consider setting up fine-tuned logging controls for your applications and scripts through clever ways of activating and deactivating loggers.



