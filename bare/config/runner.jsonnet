local common = import 'common.libsonnet';

{
  buildDirectoryPath: std.extVar('PWD') + '/worker/build',
  chrootIntoInputRoot: true,
  global: common.globalWithDiagnosticsHttpServer(':9987'),
  grpcServers: [{
    listenPaths: ['worker/runner'],
    authenticationPolicy: { allow: {} },
  }],
}
