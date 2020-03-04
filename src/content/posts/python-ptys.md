---
title: "data transfers using python spawned ptys"
date: 2020-03-01
publishdate: 2020-03-01
layout: post
categories: ["post"]
---
One task I do almost daily is trasferring data over a network. Due to customer requirements, this usually means moving data from SFTP to SFTP.

There are a lot of ways to do this. Some solutions I've implemented or reviewed are: manual CLI calls to sftp, shell scripts to automate scp calls, python scripts calling modules with dependencies on [Paramiko](https://github.com/paramiko/paramiko).


Why only python and bash? For productivity, development ease and team familiarity. I've never tried this in a compiled language but I'm sure there would be performance improvements at the expense of time.

With that said, Python and Bash have their downsides. Bash logical constructs and flow control are more clunky which makes scripts less readable and more tedious to write. With python, you gain readability and lose speed. Python becomes an additional layer of software between the user and the low level system calls required for scp functionality. Additionally, the most supported python SFTP module [Paramiko is slow](https://github.com/paramiko/paramiko/issues/175).

Enter [pexpect](https://github.com/pexpect/pexpect). Pexpect is a pure python module that allows users to spawn and control applications that are forked `ptys`. It is the python interface to `expect`.

In this case, pexpect is a nice middle ground between speed and readability because python is only responsible for spawning and interacting with the I/O of the forked process rather than acting as the interface to scp. And you still get the same speed because you're calling the scp binary.

This snippet transfers some specified local files onto a remote SFTP server:

{{< highlight python "hl_lines=30" >}}
...
@log
def put(
    files: str, arget_host: str, dest_fpath: str, user: str, password: str, recursive=False,
) -> Generator[Union[str, pexpect.EOF], None, None]:
    """Create a pty process that uses SCP to move a single file or set of files
    to a remote SFTP server.
    """
    # -v enables verbose logging
    # -p preserves modification, access times, and modes of file
    args: list = ["-v", "-p"]

    if recursive:
        # Match a directory or glob match contents
        if os.path.isdir(files):
            args.append("-r")
        else:
            raise TypeError(
                f"Recursive mode enabled but {files} is not directory. "
                f"Unexpected behavior will occur."
            )

    args.append(files)  # add source files
    args.append(f"{user}@{target_host}:{dest_fpath}")  # add destination path

    with pexpect.spawn("scp", args, timeout=120, encoding="utf-8") as pty:
        auth = False
        while True:
            try:
                pat = pty.expect(["Password:", "\(yes\/no\)\?", "\n"])
                if not auth:
                    # Authentication case
                    if pat == 0:
                        pty.sendline(password)
                        auth = True
                    # Host verification
                    if pat == 1:
                        pty.sendline("yes")
                yield pty.before
            except pexpect.EOF:
                yield pexpect.EOF
                break
    return 0

if __name__ == "__main__":
    # assume fd, sftpd, sig are defined
    put(
            fd.name,
            sftpd,
            host=sig.get("server"),
            user=sig.get("username"),
            password=sig.get("password"),
        )
{{< /highlight >}}

At a high level, `put` is a generator yielding back the standard out of each line in the forked process logging the line and or handling situations that would halt the scp process.

The highlighted line contains regex patterns to `expect` from the forked process standard out. These patterns correspond to actions that require user input and will halt the scp transfer process if they are not dealt with. In this case, those halting processes are authentication and trusted host verification. The `\n` pattern ensures that each line is `yield`ed and passed to a python logger.

Here is some log output from the above process:

{{< highlight bash >}}
19:52:38 forked.pty.process | 2020-02-09 19:52:38.640 | debug1: Authentication succeeded (keyboard-interactive).
19:52:38 forked.pty.process | 2020-02-09 19:52:38.640 | Authenticated to super.secure.host.com ([10.32.0.111]:22).
19:52:38 forked.pty.process | 2020-02-09 19:52:38.641 | debug1: channel 0: new [client-session]
19:52:38 forked.pty.process | 2020-02-09 19:52:38.641 | debug1: Entering interactive session.
19:52:38 forked.pty.process | 2020-02-09 19:52:38.641 | debug1: pledge: network
19:52:38 forked.pty.process | 2020-02-09 19:52:38.642 | debug1: Sending environment.
19:52:38 forked.pty.process | 2020-02-09 19:52:38.642 | debug1: Sending env LANG = en_US.UTF-8
19:52:38 forked.pty.process | 2020-02-09 19:52:38.642 | debug1: Sending command: scp -v -p -t some_file.csv
19:52:38 forked.pty.process | 2020-02-09 19:52:38.687 | File mtime 1581277956 atime 1581277956
19:52:38 forked.pty.process | 2020-02-09 19:52:38.687 | Sending file timestamps: T1581277956 0 1581277956 0
19:52:38 forked.pty.process | 2020-02-09 19:52:38.688 | Sending file modes: C0644 2670 some_file.csv
19:52:39 forked.pty.process | 2020-02-09 19:52:39.028 |
some_file.csv                     0%    0     0.0KB/s   --:-- ETA
some_file.csv                   100% 2670     8.0KB/s   00:00
19:52:39 forked.pty.process | 2020-02-09 19:52:39.029 | debug1: client_input_channel_req: channel 0 rtype exit-status reply 0
19:52:39 forked.pty.process | 2020-02-09 19:52:39.071 | debug1: channel 0: free: client-session, nchannels 1
19:52:39 forked.pty.process | 2020-02-09 19:52:39.072 | debug1: fd 0 clearing O_NONBLOCK
19:52:39 forked.pty.process | 2020-02-09 19:52:39.072 | debug1: fd 1 clearing O_NONBLOCK
19:52:39 forked.pty.process | 2020-02-09 19:52:39.072 | Transferred: sent 5744, received 2688 bytes, in 0.4 seconds
19:52:39 forked.pty.process | 2020-02-09 19:52:39.072 | Bytes per second: sent 13346.0, received 6245.5
19:52:39 forked.pty.process | 2020-02-09 19:52:39.072 | debug1: Exit status 0
19:52:39 forked.pty.process | 2020-02-09 19:52:39.073 | File transfer complete. Closing pexpect.spawn().
{{< /highlight >}}

Simple, readable and neat.