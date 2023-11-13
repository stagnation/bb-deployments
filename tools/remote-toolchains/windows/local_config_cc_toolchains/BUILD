HOST_CONSTRAINTS = [
  '@platforms//cpu:x86_64',
  '@platforms//os:windows',
]

platform(name = 'crosscompilation',
  # Auto-detected host platform constraints.
  constraint_values = HOST_CONSTRAINTS,
)

toolchain(
    name = "cc-toolchain-x64_windows",
    exec_compatible_with = HOST_CONSTRAINTS,
    target_compatible_with = HOST_CONSTRAINTS,
    toolchain = "@local_config_cc//:cc-compiler-x64_windows",
    toolchain_type = "@rules_cc//cc:toolchain_type",
)

toolchain(
    name = "cc-toolchain-armeabi-v7a",
    exec_compatible_with = HOST_CONSTRAINTS,
    target_compatible_with = [
        "@platforms//cpu:arm",
        "@platforms//os:android",
    ],
    toolchain = "@local_config_cc//:cc-compiler-armeabi-v7a",
    toolchain_type = "@rules_cc//cc:toolchain_type",
)
