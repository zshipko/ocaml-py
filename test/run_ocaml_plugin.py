# Run this from the github root directory via:
#    dune build test/ocaml_plugin.so && python test/run_ocaml_plugin.py
import atexit
import ctypes
import os

ocaml_is_initialized = False

def start_ocaml():
  global ocaml_is_initialized
  if ocaml_is_initialized: return
  os.environ['OCAML_PY_NO_INIT'] = 'true'
  dll = ctypes.PyDLL('_build/default/test/ocaml_plugin.so', ctypes.RTLD_GLOBAL)
  argc = ctypes.c_int(2)
  myargv = ctypes.c_char_p * 2
  argv = myargv()
  dll.caml_startup(argv)
  ocaml_is_initialized = True

  def finalize():
    dll.caml_shutdown()
  atexit.register(finalize)

start_ocaml()

import testmod

print(testmod.foobar)
print(testmod.pi)
print(testmod.e)
for i in range(1, 10):
  print(testmod.fn(i))

# OCaml errors should be nicely wrapped in Python.
try:
  testmod.fn(0)
except Exception as e:
  print('ocaml failed: ' + str(e))

capsule = testmod.build()
testmod.increment(capsule)
testmod.increment(capsule)
testmod.increment(capsule)
print(testmod.get(capsule))
