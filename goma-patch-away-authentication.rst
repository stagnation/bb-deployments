Goma and Buildbarn
~~~~~~~~~~~~~~~~~~

This follows the `goma and bromite`_ documentation,
to use `goma`'s RBE proxy to the standard bb-deployment.
We will follow the sequence, but make some adjustments to use `Buildbarn` instead of `buildgrid`.
The text below is mostly expansion on what is done for `bromite`,
but using the official tools for dependencies, the setup is explained well in Kubala's `buildgrid setup guide`_.

Though I did fail, and the section `paths diverge`_ goes into the differences,
and my trouble-shooting following that.

.. _buildgrid setup guide: `goma and buildgrid`_
.. _goma and buildgrid: https://kubala.github.io/docs/setting-up-goma
.. _goma and bromite: `bromite guide`_
.. _bromite guide: https://github.com/bromite/bromite/discussions/1032


Setup
=====

We checkout out goma server 0.13, as used by the guide.

.. TODO

Modifications
=============

We cannot use the official authenticaion flow,
so we patch the `server` to strip out authentication,
and then patch a script in the `client`.
Thankfully it is easy to recompile the `server`,
and the client can be downloaded as pre-built binaries with driver scripts,
and we only need to modify those scripts.

Paths Diverge
=============

Compiler proxy crashes on our authentication:

::

    $ export GOMA_SERVER_HOST=localhost
         export GOMA_SERVER_PORT=5050
         export GOMA_USE_SSL=false
         export GOMA_HERMETIC=error
         export GOMA_ARBITRARY_TOOLCHAIN_SUPPORT=true
         export GOMA_HTTP_AUTHORIZATION_FILE=~/.debug_goma_auth_file
         export GOMA_USE_LOCAL=false
         export GOMA_FALLBACK=true
    $ /home/nils/bin/gits/depot_tools/.cipd_bin/compiler_proxy
    E20230818 11:16:04.982394 1465866 compiler_info_cache.cc:455] failed to load cache file /run/user/1000/goma_nils/goma_cache/compiler_info_cache
    F20230818 11:16:05.005682 1465862 http_init.cc:151] Check failed: ReadFileToString(FLAGS_HTTP_AUTHORIZATION_FILE.c_str(), &auth_header) ~/.debug_goma_auth_file : you need http Authorization header in ~/.debug_goma_auth_file or unset GOMA_HTTP_AUTHORIZATION_FILE
    *** Check failure stack trace: ***
        @     0x55dabd7ab7f6  google::LogMessageFatal::~LogMessageFatal()
        @     0x55dabd667e21  devtools_goma::InitHttpClientOptions()
        @     0x55dabd64214b  devtools_goma::CompilerProxyHttpHandler::CompilerProxyHttpHandler()
        @     0x55dabd58fd27  main
        @     0x7f8fb3229d90  (unknown)
        @     0x7f8fb3229e40  __libc_start_main
        @     0x55dabd58eaaa  _start
    fish: Job 1, '/home/nils/bin/gits/depot_tools…' terminated by signal SIGABRT (Abort)

But with my old access token from a valid service account it seems okay

::

    $ set --erase GOMA_HTTP_AUTHORIZATION_FILE
    $ /home/nils/bin/gits/depot_tools/.cipd_bin/compiler_proxy
    E20230818 11:20:43.542479 1467388 compiler_info_cache.cc:455] failed to load cache file /run/user/1000/goma_nils/goma_cache/compiler_info_cache
    GOMA version 3435fce1653aa1d611c2834901561be7e6ccfab0@1686192619 is ready.
    HTTP server now listening to port 8088, access with http://localhost:8088

Strace
------

Maybe it is tilde expansion?::

    1831008 openat(AT_FDCWD, "~/.debug_goma_auth_file", O_RDONLY) = -1 ENOENT (No such file or directory)
    1831008 write(131, "Log file created at: 2023/08/18 11:35:14\nRunning on machine: white\nRunning duration (h:mm:ss): 0:00:00\nLog line format: [IWEF]yyyymmdd hh:mm:ss.uuuuuu threadid file:line] msg\nF20230818 11:35:14.166232 1831008 http_init.cc:151] Check failed: ReadFileToString(FLAGS_HTTP_AUTHORIZATION_FILE.c_str(), &auth_header) ~/.debug_goma_auth_file : you need http Authorization header in ~/.debug_goma_auth_file or unset GOMA_HTTP_AUTHORIZATION_FILE\n", 437) = 437

Switch over to `/home/nils`:
Then running the singular `compiler_proxy` works!

Start the daemons
-----------------

Still gives a failed http access to the backend
