const python_c = @import("python_c");
const PyObject = *python_c.PyObject;

const utils = @import("../../../utils/utils.zig");

const Loop = @import("../../main.zig");

const std = @import("std");


pub fn loop_time(self: ?*Loop.Python.LoopObject, _: ?PyObject) callconv(.C) ?PyObject {
    _ = self.?;

    var time: std.posix.timespec = undefined;
    std.posix.clock_gettime(.MONOTONIC, &time) catch |err| {
        utils.put_python_runtime_error_message(@errorName(err));
        return null;
    };

    const f_time: f64 = @as(f64, @floatFromInt(time.sec)) + @as(f64, @floatFromInt(time.nsec)) / std.time.ns_per_s;
    return python_c.PyFloat_FromDouble(f_time);
}
