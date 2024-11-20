local common = import 'common.libsonnet';
local runnerCount = 9;

// DO NOT USE the hardlinking configuration below unless really needed.
// This example only exists for reference in situations
// where the more efficient FUSE worker is not supported.
{
  blobstore: common.blobstore,
  browserUrl: common.browserUrl,
  maximumMessageSizeBytes: common.maximumMessageSizeBytes,
  scheduler: { address: 'scheduler:8983' },
  global: common.global,
  buildDirectories: [{
    native: {
      buildDirectoryPath: '/worker/%d/build' % index,
      cacheDirectoryPath: '/worker/%d/cache' % index,
      maximumCacheFileCount: 10000,
      maximumCacheSizeBytes: 1024 * 1024 * 1024,
      cacheReplacementPolicy: 'LEAST_RECENTLY_USED',
    },
    runners: [{
      endpoint: { address: 'unix:///worker/%d/runner' % index },
      concurrency: 1,
      instanceNamePrefix: 'hardlinking',
      platform: {
        properties: [
          { name: 'OSFamily', value: 'linux' },
          { name: 'container-image', value: 'docker://ghcr.io/catthehacker/ubuntu:act-22.04@sha256:5f9c35c25db1d51a8ddaae5c0ba8d3c163c5e9a4a6cc97acd409ac7eae239448' },
        ],
      },
      workerId: {
        datacenter: 'linkoping',
        rack: '4',
        slot: '15',
        hostname: 'ubuntu-worker%d.example.com' % index,
      },
    }],
  } for index in std.range(0, runnerCount - 1)],
  inputDownloadConcurrency: std.max(10, runnerCount),
  outputUploadConcurrency: std.max(11, runnerCount),
  directoryCache: {
    maximumCount: 1000,
    maximumSizeBytes: 1000 * 1024,
    cacheReplacementPolicy: 'LEAST_RECENTLY_USED',
  },
}
