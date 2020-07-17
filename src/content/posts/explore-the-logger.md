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

All of the messages are formatted according to the central configuration logging formatter and they were `INFO` level messagse. After activating `pkg.bar` and `pkg.baz` loggers, logger messages from only those specific loggers output. Next, I activated the `pkg.foo` logger and on the next call to each `run_statements()` function, all 3 loggers output statements. Using `deactivate_stream_log`, I deactivated all loggers and the logging went silent.

What's going on here is that I'm selectively choosing what logger(s) to stream to standard out. Why is this useful? Because this functionality gives the developer the ability to choose what modules they want to debug during runtime. Often imported dependencies contain lots of modules and when you run `getLogger("some.module")`, you often get logging statements from modules and packages you do not want. Of course, this depends on how the packages logging was implemented, but I've run into this annoyance before several times. The above pattern allows you to tune into the statements that matter to you during runtime debugging/inspection.

 I was able to do this by mutating the handlers attribute on specific loggers within the hierarchy of loggers stored in the `logging.root.manager` object. This object is responsible for building the logging hierarchy and holds all of the loggers that have been initialized during the runtime of your program. By accessing the `manager.loggerDict`, I can build different types of handlers -- in this case a `logging.StreamHandler` -- and append and pop this from the list of handlers attached to specific loggers. Here's what that object looks like in this script:

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

I mentioned I'd talk about the central logging configuration. There's plenty of [documentation](https://docs.python.org/3/library/logging.config.html) on the `logging.config` object, but at a high level, this configuration ties logger objects to logging formatters and handlers. Our configuration is loaded into each module's logger:


{{< highlight python >}}
# pkg.foo, bar, baz
logging.config.dictConfig(config.configuration.get("logging"))
{{< /highlight >}}

And when the logging hierarchy is built, `logging.root.manager` uses this configuration to instantiate `logging.Logger` objects. This is how the formatter and log level are assigned to the loggers and this affects how the messages are displayed to the user. Modifying formatters, log levels and handlers controls how the messages will be displayed to the user.

You can modify the log level and formatter in a few ways. First, directly in the configuration:

{{< highlight python >}}
...
            "lib": {
                "class": "logging.Formatter",
                "datefmt": "%Y-%m-%d %H:%M:%S",
                "format": "%(asctime)s.%(msecs)03d | %(levelname)s | %(name)s: %(message)s",
            },
        },
...
        },
        "loggers": {
            "pkg.foo": {"handlers": ["null"], "level": "INFO"},
            "pkg.bar": {"handlers": ["null"], "level": "INFO"},
            "pkg.baz": {"handlers": ["null"], "level": "INFO"}
        },
{{< /highlight >}}

Another way to do this would be to modify these things through the manager object:

{{< highlight python >}}
...
# change log level
logging.root.manager.loggerDict.get("pkg.foo").setLevel(logging.DEBUG)
logging.root.manager.loggerDict.get("pkg.bar").setLevel(logging.DEBUG)
logging.root.manager.loggerDict.get("pkg.baz").setLevel(logging.DEBUG)

# change formatter
for h in logging.root.manager.loggerDict.get("pkg.foo").handlers:
    h.setFormatter(your_formatter)
{{< /highlight >}}

There are many other ways to do this. You'll have to explore which way works best for you. YMMV.

Before ending the post, I want to talk briefly about how the messages arrive to your terminal. This happens through `logging.Handler` objects. When a logger object logs a message, each handler attached to that log, calls a `.handle()` method ([source code here](https://github.com/python/cpython/blob/master/Lib/logging/__init__.py#L1651-#L1679)). In our case, the `logging.NullHandler` gets called followed by the newly added `logging.StreamHandler` which outputs the message to our terminal. You can add any number of handlers to your logger logging each message to wherever the `.handle` method sends those log messages.

There's a lot more to the logging library than I've described here, but in general, consider setting up fine-tuned logging controls for your applications and scripts through clever ways of activating and deactivating loggers.



