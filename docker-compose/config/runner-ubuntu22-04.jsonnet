local common = import 'common.libsonnet';

// NB: These paths are best governed by the mounter.
// So with multiple isolated runners they should not know their number.
// This has two benefits: 1 it is easier to maintain this file and 2
// that it is hermetic and guaranteed by the mount isolation.
{
  buildDirectoryPath: '/worker/build',
  global: common.global,
  grpcServers: [{
    listenPaths: ['/worker/runner'],
    authenticationPolicy: { allow: {} },
  }],
}
