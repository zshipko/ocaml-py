include Py_base
module PyWrap = Py_wrap
module PyType = Py_type

let of_object : Object.t -> t = PyType.of_object
