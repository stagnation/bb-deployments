local common = import 'common.libsonnet';

{
  buildDirectoryPath: '/worker/build',
  global: common.global,
  grpcServers: [{
    listenPaths: ['/worker/runner'],
    authenticationPolicy: { allow: {} },
  }],
  chrootIntoInputRoot: true,
  inputRootMounts: [
    {
      mountpoint: 'proc',
      source: '/proc',
      filesystemType: 'proc',
    },
    {
      mountpoint: 'sys',
      source: '/sys',
      filesystemType: 'sysfs',
    },
  ],
}
