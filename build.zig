const std = @import("std");

pub fn build(b: *std.Build) void {
    {
        const target = b.resolveTargetQuery(.{ .cpu_arch = .wasm32, .os_tag = .freestanding });
        // Default to ReleaseFast so `zig build` (no flags) produces an optimised WASM.
        // Override with -Doptimize=Debug for a debuggable build.
        const optimize = b.option(
            std.builtin.OptimizeMode,
            "optimize",
            "Prioritize performance, safety, or binary size (default: ReleaseFast)",
        ) orelse .ReleaseFast;

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

        // Also copy app.wasm to js-client/ (used by examples) and project root.
        const copy_jsclient = b.addInstallFileWithDir(lib.getEmittedBin(), .{ .custom = "../js-client" }, "app.wasm");
        copy_jsclient.step.dependOn(&lib.step);
        b.getInstallStep().dependOn(&copy_jsclient.step);

        const copy_root = b.addInstallFileWithDir(lib.getEmittedBin(), .{ .custom = ".." }, "app.wasm");
        copy_root.step.dependOn(&lib.step);
        b.getInstallStep().dependOn(&copy_root.step);
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
