const std = @import("std");

pub fn build(b: *std.Build) void {
    {
        const target = b.resolveTargetQuery(.{ .cpu_arch = .wasm32, .os_tag = .freestanding });
        const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseSmall });

        const root_module = b.createModule(.{
            .root_source_file = b.path("core/wasm.zig"),
            .target = target,
            .optimize = optimize,
            .pic = true,
        });

        const lib = b.addLibrary(.{
            .name = "app",
            .root_module = root_module,
            .linkage = .dynamic,
        });
        lib.rdynamic = true;
        b.installArtifact(lib);
    }

    // Delegates to `python3 setup.py build_ext --inplace` so the output is
    // always placed at daffi/dfcore.cpython-<ver>-<platform>.so with the
    // correct ABI tag — no manual renaming required.
    {
        const py_step = b.step("python", "Build daffi.dfcore via setup.py (output: daffi/dfcore.*.so)");
        const run = b.addSystemCommand(&.{ "python3", "setup.py", "build_ext", "--inplace" });
        py_step.dependOn(&run.step);
    }
}
