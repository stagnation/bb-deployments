load("@bazel_tools//tools/sh:sh_toolchain.bzl", "sh_toolchain")

REMOTE_WINDOWS_TARGET_CONSTRAINTS = [
    "@platforms//cpu:x86_64",
    "@platforms//os:windows",
]
REMOTE_WINDOWS_EXEC_CONSTRAINTS = [
    "@platforms//cpu:x86_64",
    "@platforms//os:windows",
    # ":windows", not needed - no docker
]

sh_toolchain(
    name = "local_sh",
    path = "C:/Program Files/Git/usr/bin/bash.exe",
    visibility = ["//visibility:public"],
)

toolchain(
    name = "local_sh_toolchain",
    exec_compatible_with = REMOTE_WINDOWS_EXEC_CONSTRAINTS,
    target_compatible_with = REMOTE_WINDOWS_TARGET_CONSTRAINTS,
    toolchain = ":local_sh",
    toolchain_type = "@bazel_tools//tools/sh:toolchain_type",
)
