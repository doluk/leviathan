const python_c = @import("../../utils/python_c.zig");
const PyObject = *python_c.PyObject;

const utils = @import("../../utils/utils.zig");
const allocator = utils.allocator;

const Loop = @import("../main.zig");

pub const LEVIATHAN_LOOP_MAGIC = 0x4C4F4F5000000001;

pub const PythonLoopObject = extern struct {
    ob_base: python_c.PyObject,
    magic: u64,
    loop_obj: ?*Loop
};

inline fn z_loop_new(
    @"type": *python_c.PyTypeObject, _: ?PyObject,
    _: ?PyObject
) !*PythonLoopObject {
    const instance: *PythonLoopObject = @ptrCast(@"type".tp_alloc.?(@"type", 0) orelse return error.PythonError);
    errdefer @"type".tp_free.?(instance);

    instance.magic = LEVIATHAN_LOOP_MAGIC;
    instance.loop_obj = null;

    return instance;
}

pub fn loop_new(
    @"type": ?*python_c.PyTypeObject, args: ?PyObject,
    kwargs: ?PyObject
) callconv(.C) ?PyObject {
    const self = utils.execute_zig_function(
        z_loop_new, .{@"type".?, args, kwargs}
    );
    return @ptrCast(self);
}

pub fn loop_dealloc(self: ?*PythonLoopObject) callconv(.C) void {
    if (utils.check_leviathan_python_object(self.?, LEVIATHAN_LOOP_MAGIC)) {
        @panic("Invalid Leviathan's object");
    }
    const py_loop = self.?;

    if (py_loop.loop_obj) |loop| {
        loop.release();
    }

    const @"type": *python_c.PyTypeObject = @ptrCast(python_c.Py_TYPE(@ptrCast(self.?)) orelse unreachable);
    @"type".tp_free.?(@ptrCast(self.?));
}

inline fn z_loop_init(
    self: *PythonLoopObject, args: ?PyObject, kwargs: ?PyObject
) !c_int {
    // var loop_args_name: [11]u8 = undefined;
    // @memcpy(&loop_args_name, "io_workers\x00");
    var kwlist: [5][*c]u8 = undefined;
    kwlist[0] = @constCast("max_bytes_capacity_for_handles\x00");
    kwlist[1] = @constCast("min_bytes_capacity_for_handles\x00");
    kwlist[2] = @constCast("ready_tasks_queue_min_bytes_capacity\x00");
    kwlist[3] = @constCast("thread_safe\x00");
    kwlist[4] = null;

    var max_bytes_capacity_for_handles: u64 = 0;
    var min_bytes_capacity_for_handles: u64 = 0;
    var ready_tasks_queue_min_bytes_capacity: u64 = 0;
    var thread_safe: u8 = 0;

    if (python_c.PyArg_ParseTupleAndKeywords(
            args, kwargs, "BKKK", @ptrCast(&kwlist), &max_bytes_capacity_for_handles, &min_bytes_capacity_for_handles,
            &ready_tasks_queue_min_bytes_capacity, &thread_safe
    ) < 0) {
        return error.PythonError;
    }

    self.loop_obj = try Loop.init(
        allocator, (thread_safe != 0), @intCast(max_bytes_capacity_for_handles), @intCast(min_bytes_capacity_for_handles),
        @intCast(ready_tasks_queue_min_bytes_capacity)
    );

    return 0;
}

pub fn loop_init(
    self: ?*PythonLoopObject, args: ?PyObject, kwargs: ?PyObject
) callconv(.C) c_int {
    if (utils.check_leviathan_python_object(self.?, LEVIATHAN_LOOP_MAGIC)) {
        return -1;
    }
    const ret = utils.execute_zig_function(z_loop_init, .{self.?, args, kwargs});
    return ret;
}
