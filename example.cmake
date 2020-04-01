list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/add_module")
include(AddModule)

add_module(cstuff
  GIT master
  SIGNER 5F15F8C9C05B4D3D31EBB1C3F66D599380F88521
  file://$ENV{HOME}/repo/cstuff
  file://$ENV{HOME}/code/cstuff
  git@github.com:cyisfor/cstuff.git
  https://github.com/cyisfor/cstuff.git)
  add_cstuff(record mmapfile)

add_module(sqlite
  FOSSIL 3bfa9cc97da10598521b342961df8f5f68c7388f
  https://www.sqlite.org/src)
