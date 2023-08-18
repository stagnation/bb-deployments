Goma and Buildbarn
~~~~~~~~~~~~~~~~~~

This follows the `goma and buildgrid`_ documentation,
to use `goma`'s RBE proxy to the standard bb-deployment.
We will follow the `buildgrid` sequence, but make some adjustments,
the text below is mostly expansion on what is done for `buildgrid`,
with more details.
Though I did fail, and the section `paths diverge`_ goes into the differences,
and my trouble-shooting following that.

.. TODO: is it fixed?

Setup
=====

Buildbarn
---------

Start the docker-containers in `bb-deployemnts`::

    bb-deployments $ cd docker-compose
    docker-compose $ ./run.sh

Goma dependencies
-----------------

This is the same `setup`_ as in the `buildgrid guide`_

1) Install google's `depot tools` to manage dependencies
and working with `goma`.
The linked articles in the `buildgrid guide`_
will use this to install dependencies for `chromium` somewhere.

2) Create a GCP service account and key
   Service account: https://cloud.google.com/iam/docs/service-accounts-create
   Example service account::

        goma-authentication@goma-test-395913.iam.gserviceaccount.com Enabled 	goma-authentication 	goma authentication No keys 113492416332366018494

   We do not activate a free trial, this is just for authentication,
   and completely free.
   No roles are added to this.

3) A personal gmail account, I used one for our custom domain and it seems to work.
   Note, the `buildgrid guide`_ specifies that this account must have GCP access,
   but I do not want to submit my credit card for this attempt.
   I hope that errors stemming from this will be obvious going forward.

4) Something to build: the `chromium` project
   documentation is available here: `build chromium`_ and `additional building info`_.

.. _build chromium: https://chromium.googlesource.com/infra/goma/client#how-to-use
.. _additional building info: https://chromium.googlesource.com/chromium/src/+/master/docs/linux/build_instructions.md
.. _setup: https://kubala.github.io/docs/setting-up-rbe
.. _buildgrid guide: `goma and buildgrid`_
.. _bromite guide: https://github.com/bromite/bromite/discussions/1032

Setup Chromium
--------------

Download and skip the history. ::

    $ fetch --nohooks --no-history chromium
    $ cd src
    $ ./build/install-build-deps.sh
    $ gclient sync

    $ gn args out/Default

Architecture Overview
=====================

There are a few parts in this,
`ninja` is the main buildsystem, that will call `goma`,
which provides a compiler wrapper, `gomacc`,
(You can use that for tinkering).

The client will itself spin up two background tasks:
a `http_proxy` that connects the client to the server,
you'll notice that the ports used for the client point to this proxy,
which in-turn talks to the `goma` server, `rbe proxy`.

The `compiler proxy` too is central in this,
it includes a detailed web-page for all compile actions,
and their errors as well as server logs (info, warn, error).
But I do not know exactly how requests and shuttled to and from it.

::

    ninja

        ->  goma client
            -> http_proxy
            -> compiler_proxy

                -> goma server (rbe proxy)
                    -> Buildbarn

We use a prebuilt `goma` client,
but it is possible to `build it too`_.

.. _build it too: https://chromium.googlesource.com/infra/goma/client#how-to-build

Practical steps
===============

PATH
----

After the setup we can now start the `goma` processes
add the `depot_tools` repository to PATH ::

    $ export PATH=.../depot_tools:$PATH

We will use some of these commands,
and they will look for sub-commands on `$PATH`.
But the repo is filled with stuff that may conflict with your other tools,
so avoid adding it globally.

Run the goma server
-------------------

We checkout out goma server 0.13, as used by the guide.

First, to work with `Buildbarn` we need a simple patch,
patch the `OSFamily` platform property to lowercase::
In the `goma` server repository::

    commit 8d1ba1eb6aed0b504448f464ae365e9af705788c (HEAD)
    Author: Nils Wireklint <nils@meroton.com>
    Date:   Tue Aug 15 11:50:19 2023 +0200

        Fix OSFamily value capitalization

        In accordance with the REv2 API the standard value of the OSFamily
        platform property should be lowercase.

        See
        https://github.com/bazelbuild/remote-apis/blob/068363a3625e166056c155f6441cfb35ca8dfbf2/build/bazel/remote/execution/v2/platform.md

    diff --git a/cmd/remoteexec_proxy/main.go b/cmd/remoteexec_proxy/main.go
    index 4ab92a2..d321344 100644
    --- a/cmd/remoteexec_proxy/main.go
    +++ b/cmd/remoteexec_proxy/main.go
    @@ -412,7 +412,7 @@ func main() {
                                                            Value: *platformContainerImage,
                                                    }, {
                                                            Name:  "OSFamily",
    -                                                       Value: "Linux",
    +                                                       Value: "linux",
                                                    },
                                            },
                                    },
    {

Run the `goma` server (to proxy to RBE)::

    goma/server $ go run \
        cmd/remoteexec_proxy/main.go \
        -port 5050 \
        -remoteexec-addr localhost:8980 \
        -remote-instance-name "hardlinking" \
        -platform-container-image 'docker://ghcr.io/catthehacker/ubuntu:act-22.04@sha256:5f9c35c25db1d51a8ddaae5c0ba8d3c163c5e9a4a6cc97acd409ac7eae239448' \
        -insecure-remoteexec \
        -service-account-json <path_to_service_account_json> \
        -whitelisted-users <your_gmail_email_address>

This follows the `buildgrid example`_ but sets the container image platform property,
rather than `patching it away`_

This should say that it is running, accepts you and can talk RBE::

    2023-08-17T11:33:40.842+0200    INFO    remoteexec_proxy/main.go:277    allow access for ["nils@meroton.com"] / domains []
    ...
    2023-08-17T11:33:40.842+0200    INFO    exec/inventory.go:190   configure platform config: target:{addr:"grpc://127.0.0.1:8980"}  build_info:{}  remoteexec_platform:{properties:{name:"container-image"  value:"docker://ghcr.io/catthehacker/ubuntu:act-22.04@sha256:5f9c35c25db1d51a8ddaae5c0ba8d3c163c5e9a4a6cc97acd409ac7eae239448"}  properties:{name:"OSFamily"  value:"linux"}  rbe_instance_basename:"hardlinking"}  dimensions:"os:linux"

.. _buildgrid example: `goma and buildgrid`_

Login and start the goma client
-------------------------------

Start the `goma` client
We login and refer to the server (which must be running) ::

    chromium/src $ export GOMA_SERVER_HOST="localhost"
                   export GOMA_SERVER_PORT="5050"
                   export GOMA_USE_SSL="false"
                   export GOMA_ARBITRARY_TOOLCHAIN_SUPPORT=true
                   export GOMA_USE_LOCAL=false

    $ goma_auth login

The environment variables combined with the whitelist above will allow
you to use `goma` on your own computer.
This will use an `OAuth` authentication with google to your personal email,
and some token will be saved for you.
Following the login instructions (and use `ssh` port forwarding if needed)
the webpage will print::

    The authentication flow has completed.

And the console for `goma_auth`::

    Login as nils@meroton.com
    Ready to use Goma service at http://localhost:5050

I never go an access code, which the `buildgrid guide`_ describes.

We can then start the `goma` client,
run `goma_ctl ensure_start`.
This will also check that the `compiler_proxy` is setup,
which includes a webpage to look at all `goma` actions.

::

    $ goma_ctl ensure_start
    INFO: creating cache dir (/run/user/1000/goma_nils/goma_cache).

    Enable http_proxy
    override GOMA_SERVER_HOST=127.0.0.1
    override GOMA_SERVER_PORT=19080
    override GOMA_USE_SSL=false
    GOMA version 3435fce1653aa1d611c2834901561be7e6ccfab0@1686192619
    server: localhost:5050 (via http_proxy)

The override of the port here means that `goma` client will send the data to the `http_proxy`,
which in turns knows that the `goma` server resides on port 5050.

Paths diverge
-------------

This is where my setup starts to diverge from the success
in the `buildgrid guide`_.

Goma compiler proxy
+++++++++++++++++++

First, the compiler proxy has some problems in bring-up.

`goma_ctl ensure_start` retries with error messages like the following::

    waiting for compiler_proxy port (timeout in 69)...

or::

    goma is not in healthy state: running:
    Killing compiler proxy.
    compiler proxy status: http://127.0.0.1:8088 quit!
    Wait for compiler_proxy process to terminate...
    ...
    waiting for compiler_proxy port (timeout in 40)...
    waiting for compiler_proxy port (timeout in 39)...

They then finish with "goma is ready"
after a long timeout.::

    compiler proxy (pid=1264673) status: http://127.0.0.1:8088 running: access to backend servers was failed:502

    Now goma is ready!

After that the process pops up, note that `8088` can carry the "omniorb" well-known port name. ::

    $ netstat -ltp
    tcp        0      0 localhost:omniorb       0.0.0.0:*               LISTEN      3284998/compiler_pr

Use `--numeric-ports` to show the number 8088 instead.

Aside: Most chromium developers use GCP
+++++++++++++++++++++++++++++++++++++++

https://chromium.googlesource.com/infra/goma/client/+/HEAD/doc/early-access-guide.md
This is not something that we want,
but may be part of the control flow that no longer works for us.

Backend ping
++++++++++++

It seems that `goma` also checks for a backend compiler service::

    E20230815 12:50:49.545905  7046 compiler_proxy_http_handler.cc:478] Going to retry ping. http_status_code=502 num_retry=15
    E20230815 12:50:49.545943  7046 compiler_proxy_http_handler.cc:484] HTTP error=502: Cannot connect to server at /cxx-compiler-service/ping num_retry=16

And the code indicates that this is hosted by google::

      # e.g. url='https://goma.chromium.org/cxx-compiler-service/ping'
      path_prefix = os.environ.get('GOMA_URL_PATH_PREFIX', '/cxx-compiler-service')

We should find a way to not use it at all,
or use a local setup.

This may or may not be relevant, as the login programs says that we can use `goma`,
but all builds fail with `http error 502`.

This has me stumped, and all actions later built with `ninja` + `goma`
will fail with `http` errors.

They can be seen here: http://localhost:8088/#finished
And fail::

    error_message:
        compiler_proxy [11.157638ms]: no retry: exec error=0 retry=0 reason=RPC failed http=502: Got HTTP error:502 http=unhealthy
        http_status	502

Do I need GCP for my personal account?
++++++++++++++++++++++++++++++++++++++

Possibly, but nothing indicates it.
The url error just points to `/cxx-compiler-service/ping`
which is not a common endpoint anywhere.
I do not know what will satisfy it.

Error logs
----------

Goma has error logs, in its run directory: `/run/user/1000/goma_$USER/`
as well as in the `compiler proxy` web-page: http://localhost:8088/logz?ERROR

::

    Log file created at: 2023/08/17 11:45:20
    Running on machine: white
    Running duration (h:mm:ss): 0:00:00
    Log line format: [IWEF]yyyymmdd hh:mm:ss.uuuuuu threadid file:line] msg
    E20230817 11:45:20.994307 1264678 compiler_info_cache.cc:455] failed to load cache file /run/user/1000/goma_nils/goma_cache/compiler_info_cache
    E20230817 11:45:21.839116 1264673 compiler_proxy_http_handler.cc:478] Going to retry ping. http_status_code=502 num_retry=0
    E20230817 11:45:23.019373 1264673 compiler_proxy_http_handler.cc:478] Going to retry ping. http_status_code=502 num_retry=1
    E20230817 11:45:24.491596 1264673 compiler_proxy_http_handler.cc:478] Going to retry ping. http_status_code=502 num_retry=2
    E20230817 11:45:26.512697 1264673 compiler_proxy_http_handler.cc:478] Going to retry ping. http_status_code=502 num_retry=3
    E20230817 11:45:29.302037 1264673 compiler_proxy_http_handler.cc:478] Going to retry ping. http_status_code=502 num_retry=4
    E20230817 11:45:33.167049 1264673 compiler_proxy_http_handler.cc:478] Going to retry ping. http_status_code=502 num_retry=5
    E20230817 11:45:38.267271 1264673 compiler_proxy_http_handler.cc:478] Going to retry ping. http_status_code=502 num_retry=6
    E20230817 11:45:43.367502 1264673 compiler_proxy_http_handler.cc:478] Going to retry ping. http_status_code=502 num_retry=7
    E20230817 11:45:48.467741 1264673 compiler_proxy_http_handler.cc:478] Going to retry ping. http_status_code=502 num_retry=8
    E20230817 11:45:53.567960 1264673 compiler_proxy_http_handler.cc:478] Going to retry ping. http_status_code=502 num_retry=9
    E20230817 11:45:58.668177 1264673 compiler_proxy_http_handler.cc:478] Going to retry ping. http_status_code=502 num_retry=10
    E20230817 11:46:03.768399 1264673 compiler_proxy_http_handler.cc:478] Going to retry ping. http_status_code=502 num_retry=11
    E20230817 11:46:08.868633 1264673 compiler_proxy_http_handler.cc:478] Going to retry ping. http_status_code=502 num_retry=12
    E20230817 11:46:13.968878 1264673 compiler_proxy_http_handler.cc:478] Going to retry ping. http_status_code=502 num_retry=13
    E20230817 11:46:19.069134 1264673 compiler_proxy_http_handler.cc:478] Going to retry ping. http_status_code=502 num_retry=14
    E20230817 11:46:24.169440 1264673 compiler_proxy_http_handler.cc:478] Going to retry ping. http_status_code=502 num_retry=15
    E20230817 11:46:24.169474 1264673 compiler_proxy_http_handler.cc:484] HTTP error=502: Cannot connect to server at /cxx-compiler-service/ping num_retry=16

Warning logs
------------

::

    W20230817 11:45:21.120471 1264680 http.cc:2000] ping read  http=502 path=/cxx-compiler-service/ping Details:HTTP/1.1 502 Bad Gateway\r\nDate: Thu, 17 Aug 2023 09:45:21 GMT\r\nContent-Length: 0\r\n\r\n
    W20230817 11:45:21.139039 1264673 http_rpc.cc:249] Update health status:running: access to backend servers was failed:502
    W20230817 11:45:21.139061 1264681 http_rpc.cc:267] http=502
    W20230817 11:45:21.139072 1264681 http_rpc.cc:269] http err_message=Got HTTP error:502
    W20230817 11:45:21.139077 1264681 http_rpc.cc:271] http response header=HTTP/1.1 502 Bad Gateway

Health Check
------------

http://localhost:8088/#network-stats ::

    status: running: had some http errors from backend servers

http configuration
------------------

The `compiler_proxy` has a `httprpcz` end point with some more details
http://localhost:8088/httprpcz

::

    [http configuration]

    Status:error: access to backend servers was rejected.
    Remote host: 127.0.0.1:19080 /cxx-compiler-service



Details and Errors
==================

Status
------

Can be checked with `goma_ctl`::

    $ goma_ctl status
    compiler proxy (pid=145346,6613) status: http://127.0.0.1:8088 running: access to backend servers was failed:502

User access
-----------

Can be checked with `goma_auth`::

    # Without the proxy
    $ goma_auth info
    Login as nils@meroton.com
    Current user is not registered with Goma service at https://goma.chromium.org with GOMA_RPC_EXTRA_PARAMS="". Unable to use Goma.

    # With the RBE proxy running
    $ goma_auth info
    Login as nils@meroton.com
    Ready to use Goma service at http://localhost:5050

Instance Name
+++++++++++++

The instance name is handled as a path segment,
so the empty instance name typically used will be converted to a dot ".".
.. TODO : So we use the fuse


Footnotes
=========

.. _goma and buildgrid: https://kubala.github.io/docs/setting-up-goma
.. _building Goma client: https://chromium.googlesource.com/infra/goma/client#build
.. _building Goma server: https://chromium.googlesource.com/infra/goma/server/

.. NB: There is no anchor for the heading 'Patching Goma'
.. _patching it away: https://kubala.github.io/docs/setting-up-goma


Errors I encountered
====================

Goma account
------------

The login gives an error about `goma.chromium.org`::

    Login as nils@meroton.com
    Current user is not registered with Goma service at
    https://goma.chromium.org with GOMA_RPC_EXTRA_PARAMS="". Unable to use Goma.

This is because the environment variables do not point to the local server.
It tried to authenticate you to the official goma server.
