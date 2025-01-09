const Loop = @import("../main.zig");

const python_c = @import("python_c");
const PyObject = *python_c.PyObject;

const Constructors = @import("constructors.zig");
const Scheduling = @import("scheduling.zig");
const Control = @import("control.zig");
const Utils = @import("utils/main.zig");

const PythonLoopMethods: []const python_c.PyMethodDef = &[_]python_c.PyMethodDef{
    // --------------------- Control ---------------------
    python_c.PyMethodDef{
        .ml_name = "run_forever\x00",
        .ml_meth = @ptrCast(&Control.loop_run_forever),
        .ml_doc = "Run the event loop forever.\x00",
        .ml_flags = python_c.METH_NOARGS
    },
    python_c.PyMethodDef{
        .ml_name = "stop\x00",
        .ml_meth = @ptrCast(&Control.loop_stop),
        .ml_doc = "Stop the event loop.\x00",
        .ml_flags = python_c.METH_NOARGS
    },
    python_c.PyMethodDef{
        .ml_name = "is_running\x00",
        .ml_meth = @ptrCast(&Control.loop_is_running),
        .ml_doc = "Return True if the event loop is currently running.\x00",
        .ml_flags = python_c.METH_NOARGS
    },
    python_c.PyMethodDef{
        .ml_name = "is_closed\x00",
        .ml_meth = @ptrCast(&Control.loop_is_closed),
        .ml_doc = "Return True if the event loop was closed.\x00",
        .ml_flags = python_c.METH_NOARGS
    },
    python_c.PyMethodDef{
        .ml_name = "close\x00",
        .ml_meth = @ptrCast(&Control.loop_close),
        .ml_doc = "Close the event loop\x00",
        .ml_flags = python_c.METH_NOARGS
    },

    // --------------------- Sheduling ---------------------
    python_c.PyMethodDef{
        .ml_name = "call_soon\x00",
        .ml_meth = @ptrCast(&Scheduling.loop_call_soon),
        .ml_doc = "Schedule callback to be called with args arguments at the next iteration of the event loop.\x00",
        .ml_flags = python_c.METH_FASTCALL | python_c.METH_KEYWORDS
    },
    python_c.PyMethodDef{
        .ml_name = "call_soon_threadsafe\x00",
        .ml_meth = @ptrCast(&Scheduling.loop_call_soon_threadsafe),
        .ml_doc = "Thread-safe variant of `call_soon`.\x00",
        .ml_flags = python_c.METH_FASTCALL | python_c.METH_KEYWORDS
    },
    python_c.PyMethodDef{
        .ml_name = "call_later\x00",
        .ml_meth = @ptrCast(&Scheduling.loop_call_later),
        .ml_doc = "Thread-safe variant of `call_soon`.\x00",
        .ml_flags = python_c.METH_FASTCALL | python_c.METH_KEYWORDS
    },
    python_c.PyMethodDef{
        .ml_name = "call_at\x00",
        .ml_meth = @ptrCast(&Scheduling.loop_call_at),
        .ml_doc = "Thread-safe variant of `call_soon`.\x00",
        .ml_flags = python_c.METH_FASTCALL | python_c.METH_KEYWORDS
    },

    // --------------------- Utils ---------------------
    python_c.PyMethodDef{
        .ml_name = "time\x00",
        .ml_meth = @ptrCast(&Utils.Time.loop_time),
        .ml_doc = "Return the current time, as a float value, according to the event loop’s internal monotonic clock.\x00",
        .ml_flags = python_c.METH_NOARGS
    },
    python_c.PyMethodDef{
        .ml_name = "create_future\x00",
        .ml_meth = @ptrCast(&Utils.Future.loop_create_future),
        .ml_doc = "Schedule callback to be called with args arguments at the next iteration of the event loop.\x00",
        .ml_flags = python_c.METH_NOARGS
    },
    python_c.PyMethodDef{
        .ml_name = "create_task\x00",
        .ml_meth = @ptrCast(&Utils.Task.loop_create_task),
        .ml_doc = "Schedule callback to be called with args arguments at the next iteration of the event loop.\x00",
        .ml_flags = python_c.METH_FASTCALL | python_c.METH_KEYWORDS
    },

    // --------------------- Sentinel ---------------------
    python_c.PyMethodDef{
        .ml_name = null, .ml_meth = null, .ml_doc = null, .ml_flags = 0
    }
};

pub const LoopObject = extern struct {
    ob_base: python_c.PyObject,
    data: [@sizeOf(Loop)]u8,

    asyncio_module: ?PyObject,
    invalid_state_exc: ?PyObject,
    cancelled_error_exc: ?PyObject,
    
    enter_task_func: ?PyObject,
    leave_task_func: ?PyObject,

    contextvars_module: ?PyObject,
    contextvars_copy: ?PyObject,
    exception_handler: ?PyObject,

    task_name_counter: u64,
};

pub var LoopType = python_c.PyTypeObject{
    .tp_name = "leviathan.Loop\x00",
    .tp_doc = "Leviathan's loop class\x00",
    .tp_basicsize = @sizeOf(LoopObject),
    .tp_itemsize = 0,
    .tp_flags = python_c.Py_TPFLAGS_DEFAULT | python_c.Py_TPFLAGS_BASETYPE | python_c.Py_TPFLAGS_HAVE_GC,
    .tp_new = &Constructors.loop_new,
    .tp_traverse = @ptrCast(&Constructors.loop_traverse),
    .tp_clear = @ptrCast(&Constructors.loop_clear),
    .tp_init = @ptrCast(&Constructors.loop_init),
    .tp_dealloc = @ptrCast(&Constructors.loop_dealloc),
    .tp_methods = @constCast(PythonLoopMethods.ptr)
};

