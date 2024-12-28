const python_c = @import("python_c");
const PyObject = *python_c.PyObject;

const Future = @import("../main.zig");
const PythonFutureObject = Future.FutureObject;

const utils = @import("../../utils/utils.zig");


inline fn raise_cancel_exception(self: *PythonFutureObject) void {
    if (self.cancel_msg_py_object) |cancel_msg_py_object| {
        python_c.PyErr_SetObject(self.cancelled_error_exc.?, cancel_msg_py_object);
    }else{
        python_c.PyErr_SetRaisedException(self.cancelled_error_exc.?);
    }
}

pub inline fn get_result(self: *PythonFutureObject) ?PyObject {
    const future_data = utils.get_data_ptr(Future, self);
    return switch (future_data.status) {
        .PENDING => blk: {
            python_c.PyErr_SetString(self.invalid_state_exc.?, "Result is not ready.\x00");
            break :blk null;
        },
        .FINISHED => blk: {
            if (self.exception) |exc| {
                const new_exc = python_c.py_newref(exc);
                if (self.exception_tb) |exception_tb| {
                    if (python_c.PyException_SetTraceback(new_exc, exception_tb) < 0) {
                        utils.put_python_runtime_error_message(
                            "An error ocurred setting traceback to python exception\x00"
                        );
                        break :blk null;
                    }
                }
                python_c.PyErr_SetRaisedException(new_exc);
                break :blk null;
            }
            break :blk @as(PyObject, @alignCast(@ptrCast(future_data.result.?)));
        },
        .CANCELED => blk: {
            raise_cancel_exception(self);
            break :blk null;
        }
    };
}


pub fn future_result(self: ?*PythonFutureObject, _: ?PyObject) callconv(.C) ?PyObject {
    const instance = self.?;
    const future_data = utils.get_data_ptr(Future, instance);
    const mutex = &future_data.mutex;
    mutex.lock();
    defer mutex.unlock();

    return get_result(instance);
}

pub fn future_exception(self: ?*PythonFutureObject, _: ?PyObject) callconv(.C) ?PyObject {
    const instance = self.?;

    const future_data = utils.get_data_ptr(Future, instance);
    const mutex = &future_data.mutex;
    mutex.lock();
    defer mutex.unlock();

    return switch (future_data.status) {
        .PENDING => blk: {
            python_c.PyErr_SetString(instance.invalid_state_exc.?, "Exception is not set.\x00");
            break :blk null;
        },
        .FINISHED => blk: {
            if (instance.exception) |exc| {
                break :blk python_c.py_newref(exc);
            }
            break :blk python_c.get_py_none();
        },
        .CANCELED => blk: {
            raise_cancel_exception(instance);
            break :blk null;
        }
    };
}

pub inline fn future_fast_set_exception(self: *PythonFutureObject, obj: *Future, exception: PyObject) !i8 {
    self.exception = python_c.py_newref(exception);
    errdefer python_c.py_decref_and_set_null(&self.exception);

    self.exception_tb = python_c.PyException_GetTraceback(exception);
    errdefer python_c.py_decref_and_set_null(&self.exception_tb);

    try obj.call_done_callbacks(.FINISHED);
    return 0;
}

inline fn z_future_set_exception(self: *PythonFutureObject, args: ?PyObject) !PyObject {
    const future_data = utils.get_data_ptr(Future, self);
    const mutex = &future_data.mutex;
    mutex.lock();
    defer mutex.unlock();

    switch (future_data.status) {
        .FINISHED,.CANCELED => {
            python_c.PyErr_SetString(self.invalid_state_exc.?, "Exception already setted\x00");
            return error.PythonError;
        },
        else => {}
    }

    var exception: ?PyObject = null;
    if (python_c.PyArg_ParseTuple(args.?, "O:exception\x00", &exception) < 0) {
        return error.PythonError;
    }

    _ = try future_fast_set_exception(self, future_data, exception.?);
    return python_c.get_py_none();
}

pub fn future_set_exception(self: ?*PythonFutureObject, args: ?PyObject) callconv(.C) ?PyObject {
    return utils.execute_zig_function(z_future_set_exception, .{self.?, args});
}

pub inline fn future_fast_set_result(obj: *Future, result: PyObject) !void {
    obj.result = python_c.py_newref(result);
    errdefer python_c.py_decref_and_set_null(@alignCast(@ptrCast(&obj.result)));

    try obj.call_done_callbacks(.FINISHED);
}

inline fn z_future_set_result(self: *PythonFutureObject, args: ?PyObject) !PyObject {
    const future_data = utils.get_data_ptr(Future, self);
    const mutex = &future_data.mutex;
    mutex.lock();
    defer mutex.unlock();

    switch (future_data.status) {
        .FINISHED,.CANCELED => {
            python_c.PyErr_SetString(self.invalid_state_exc.?, "Result already setted\x00");
            return error.PythonError;
        },
        else => {}
    }

    var result: ?PyObject = undefined;
    if (python_c.PyArg_ParseTuple(args.?, "O:result\x00", &result) < 0) {
        return error.PythonError;
    }

    try future_fast_set_result(future_data, result.?);
    return python_c.get_py_none();
}

pub fn future_set_result(self: ?*PythonFutureObject, args: ?PyObject) callconv(.C) ?PyObject {
    return utils.execute_zig_function(z_future_set_result, .{self.?, args});
}

pub fn future_done(self: ?*PythonFutureObject, _: ?PyObject) callconv(.C) ?PyObject {
    const future_data = utils.get_data_ptr(Future, self.?);
    const mutex = &future_data.mutex;
    mutex.lock();
    defer mutex.unlock();

    return switch (future_data.status) {
        .FINISHED,.CANCELED => python_c.get_py_true(),
        else => python_c.get_py_false()
    };
}
