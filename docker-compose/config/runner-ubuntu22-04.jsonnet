local common = import 'common.libsonnet';

{
  buildDirectoryPath: '/worker/build',
  chrootIntoInputRoot: true,
  global: common.global,
  grpcServers: [{
    listenPaths: ['/worker/runner'],
    authenticationPolicy: { allow: {} },
  }],
}
