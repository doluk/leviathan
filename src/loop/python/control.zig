const python_c = @import("../../utils/python_c.zig");
const PyObject = *python_c.PyObject;

const utils = @import("../../utils/utils.zig");
const allocator = utils.allocator;

const Loop = @import("../main.zig");
const Handle = @import("../../handle/main.zig");

const constructors = @import("constructors.zig");
const PythonLoopObject = constructors.PythonLoopObject;
const LEVIATHAN_LOOP_MAGIC = constructors.LEVIATHAN_LOOP_MAGIC;

const std = @import("std");


pub fn loop_run_forever(self: ?*PythonLoopObject, _: ?PyObject) callconv(.C) ?PyObject {
    const instance = self.?;
    if (utils.check_leviathan_python_object(instance, LEVIATHAN_LOOP_MAGIC)) {
        return null;
    }

    const loop_obj = instance.loop_obj.?;
    loop_obj.run_forever() catch return null;

    return python_c.get_py_none();
}


pub fn loop_stop(self: ?*PythonLoopObject, _: ?PyObject) callconv(.C) ?PyObject {
    const instance = self.?;
    if (utils.check_leviathan_python_object(instance, LEVIATHAN_LOOP_MAGIC)) {
        return null;
    }

    const loop_obj = instance.loop_obj.?;

    const mutex = &loop_obj.mutex;
    mutex.lock();
    defer mutex.unlock();

    loop_obj.stopping = true;
    return python_c.get_py_none();
}

pub fn loop_is_running(self: ?*PythonLoopObject, _: ?PyObject) callconv(.C) ?PyObject {
    const instance = self.?;
    if (utils.check_leviathan_python_object(instance, LEVIATHAN_LOOP_MAGIC)) {
        return null;
    }

    const loop_obj = instance.loop_obj.?;
    const mutex = &loop_obj.mutex;
    mutex.lock();
    defer mutex.unlock();

    return python_c.PyBool_FromLong(@intCast(@intFromBool(loop_obj.running)));
}

pub fn loop_is_closed(self: ?*PythonLoopObject, _: ?PyObject) callconv(.C) ?PyObject {
    const instance = self.?;
    if (utils.check_leviathan_python_object(instance, LEVIATHAN_LOOP_MAGIC)) {
        return null;
    }

    const loop_obj = instance.loop_obj.?;

    const mutex = &loop_obj.mutex;
    mutex.lock();
    defer mutex.unlock();

    return python_c.PyBool_FromLong(@intCast(@intFromBool(loop_obj.closed)));
}

pub fn loop_close(self: ?*PythonLoopObject, _: ?PyObject) callconv(.C) ?PyObject {
    const instance = self.?;
    if (utils.check_leviathan_python_object(instance, LEVIATHAN_LOOP_MAGIC)) {
        return null;
    }

    const loop_obj = instance.loop_obj.?;

    const mutex = &loop_obj.mutex;
    {
        mutex.lock();
        defer mutex.unlock();

        if (loop_obj.running) {
            utils.put_python_runtime_error_message("Loop is running\x00");
            return null;
        }

        const queue = &loop_obj.ready_tasks_queues[loop_obj.ready_tasks_queue_to_use];
        var node = queue.first;
        while (node) |n| {
            const handle: *Handle = @alignCast(@ptrCast(n.data.?));
            const handle_mutex = &handle.mutex;
            handle_mutex.lock();
            handle.cancelled = true;
            handle_mutex.unlock();

            node = n.next;
        }
    }

    loop_obj.run_forever() catch return null;

    mutex.lock();
    loop_obj.release();
    mutex.unlock();

    return python_c.get_py_none();
}
