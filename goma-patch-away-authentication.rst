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

We checkout out `goma server` `origin/main`.
There have been many recent changes from people working with various `RBE` projects.

.. TODO

Modifications
=============

We cannot use the official authentication flow,
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

::

    $ /home/nils/bin/gits/depot_tools/.cipd_bin/compiler_proxy
    GOMA version 3435fce1653aa1d611c2834901561be7e6ccfab0@1686192619 is ready.
    HTTP server now listening to port 8088, access with http://localhost:8088;

Start the daemons
-----------------

Still gives a failed http access to the backend

Check that the host is configured::

    $ /home/nils/bin/gits/depot_tools/.cipd_bin/compiler_proxy --print-server-host
    localhost:5050

It seems that mainly `auth.py` uses the `/cxx-compiler-service` endpoint
and we do patch it all away.
Double check that all versions are patched, to avoid unexpected PATH traversal or whatever.::

    locate goma_auth.py | xargs wc -l
      5 /CAS/bin/goma_auth.py
      # [Editor's Note] Seems like I have deleted the android version here.
      5 /CAS/chromium/src/third_party/depot_tools/.cipd_bin/goma_auth.py
      5 /CAS/chromium/src/third_party/depot_tools/.cipd_bin/android/goma_auth.py
      5 /CAS/depot_tools/.cipd_bin/goma_auth.py
      5 /CAS/depot_tools/.cipd_bin/android/goma_auth.py
      5 /CAS/goma/client/client/goma_auth.py
      5 /CAS/goma/client/out/Release/goma_auth.py
      5 /home/nils/bin/gits/depot_tools/.cipd_bin/goma_auth.py
      5 /home/nils/bin/gits/depot_tools/.cipd_bin/android/goma_auth.py

But there is still some code in the `goma client` to access this.
And get something back.

The `server is meant to provide this endpoint in `frontend.go::Register`
And our patches should make sure that we send something to "authorize" the `client`.

But the problem "bad gateway" indicates that it does not reach the `server`.

Remaining Authentication
------------------------

This ping can be done manually with `curl`::

    $ curl -XPOST \
        --user-agent 'compiler-proxy built by chrome-bot at 3435fce1653aa1d611c2834901561be7e6ccfab0@1686192619 on 2023-06-08T03:08:16.790750Z ' \
        'localhost:5050/cxx-compiler-service/ping'
    ok

But it fails without the port.
So some environment variable setup within the `client` loses the port.

It is good to know that the `rbe_proxy` operates when we hit it.
But maybe the error is in the communication with the `http proxy`,
which does not receive, or does not propagate, the ping.

Setting `GOMA_URL_PATH_PREFIX` to include the port
fails quickly with error 400: bad request.

Note that `wireshark` says that the original request is sent to destination port `19080`,
so the bad gateway seems the be the `http_proxy`.

Try to torubleshoot the http proxy individually
-----------------------------------------------

::

    # first terminal
    $ out/Release/http_proxy -port 10000 -server-host 127.0.0.1:5050
    2023/08/18 15:28:11 getrlimit(RLIMIT_NOFILE)={cur: 1048576, max: 1048576}

    # other terminal
    $ curl -XPOST \
        --user-agent 'compiler-proxy built by chrome-bot at 3435fce1653aa1d611c2834901561be7e6ccfab0@1686192619 on 2023-06-08T03:08:16.790750Z ' \
        'localhost:10000/cxx-compiler-service/ping'

    # first terminal
    2023/08/18 15:28:14 http: proxy error: tls: first record does not look like a TLS handshake

USE_SSL=false?
