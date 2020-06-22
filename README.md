You know how with git submodules, you mark a specific commit hash or branch, and also a specific URL to fetch it from? You know how in Go, you require a specific URL with a single host? You know how if the single sole hosting provider of that URL goes down, your program stops working?

```
add_module(subdirectory
  GIT somecommithash1234
  file://$ENV{HOME}/.local/repo/subdirectory
  https://supercoolhost.info/~supercooldud/subdirectory.git
  https://gitlab.com/supercooldud/subdirectory.git
  https://github.com/supercooldud/subdirectory.git)
```

It tries to clone each URL in order, checking out the specified commit hash, and failing if it isn’t found. The module is cloned into `${CMAKE_CURRENT_BUILD_DIR}/modules` which for the most part seems to work fine.
