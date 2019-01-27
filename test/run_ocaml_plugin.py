# Run this from the github root directory via:
#    dune build test/ocaml_plugin.so && python test/run_ocaml_plugin.py
import ctypes
import os

os.environ['OCAML_PY_NO_INIT'] = 'true'

print('Importing the ocaml library.')
dll = ctypes.PyDLL('_build/default/test/ocaml_plugin.so', ctypes.RTLD_GLOBAL)

print('Starting the ocaml runtime.')
argc = ctypes.c_int(2)
myargv = ctypes.c_char_p * 2
argv = myargv()
dll.caml_startup(argv)

print('Importing the ocaml module.');
import testmod

print('Module imported has been imported.')
print(testmod.foobar)

print('All good, shutting down the ocaml runtime.')
dll.caml_shutdown()
