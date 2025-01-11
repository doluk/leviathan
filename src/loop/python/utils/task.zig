const python_c = @import("python_c");
const PyObject = *python_c.PyObject;

const utils = @import("../../../utils/utils.zig");

const Loop = @import("../../main.zig");
const Task = @import("../../../task/main.zig");

const PythonLoopObject = Loop.Python.LoopObject;
const PythonTaskObject = Task.PythonTaskObject;

inline fn z_loop_create_task(
    self: *PythonLoopObject, args: []?PyObject,
    knames: ?PyObject
) !*PythonTaskObject {
    if (args.len != 1) {
        utils.put_python_runtime_error_message("Invalid number of arguments\x00");
        return error.PythonError;
    }

    var context: ?PyObject = null;
    var name: ?PyObject = null;
    try python_c.parse_vector_call_kwargs(
        knames, args.ptr + args.len,
        &.{"context\x00", "name\x00"},
        &.{&context, &name},
    );
    errdefer python_c.py_xdecref(name);

    if (context) |py_ctx| {
        if (python_c.Py_IsNone(py_ctx) != 0) {
            context = python_c.PyObject_CallNoArgs(self.contextvars_copy.?)
                orelse return error.PythonError;
            python_c.py_decref(py_ctx);
        }else{
            python_c.py_incref(py_ctx);
        }
    }else {
        context = python_c.PyObject_CallNoArgs(self.contextvars_copy.?) orelse return error.PythonError;
    }
    errdefer python_c.py_decref(context.?);

    if (name) |v| {
        if (python_c.PyUnicode_Check(v) == 0) {
            python_c.PyErr_SetString(python_c.PyExc_TypeError, "name must be a string\x00");
            return error.PythonError;
        }
    }

    const coro: PyObject = python_c.py_newref(args[0].?);
    errdefer python_c.py_decref(coro);

    const task = try Task.Constructors.fast_new_task(self, coro, context.?, name);
    return task;
}

pub fn loop_create_task(
    self: ?*PythonLoopObject, args: ?[*]?PyObject, nargs: isize, knames: ?PyObject
) callconv(.C) ?*PythonTaskObject {
    return utils.execute_zig_function(z_loop_create_task, .{
        self.?, args.?[0..@as(usize, @intCast(nargs))], knames
    });
}
