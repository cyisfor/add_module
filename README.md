You know how with git submodules, you mark a specific commit hash or branch, and also a specific URL to fetch it from? You know how in Go, you require a specific URL without a commit hash? You know how if the hosting provider of that URL goes down, your program stops working? How if they become corrupt, infiltrated, or sold out, your program (any program) becomes malware for all your users?

Yeah that’s a pretty f-ing dumb idea.

So I can’t fix Go, but I can provide a slightly less odious alternative using cmake.

```
add_module(subdirectory
  GIT somecommithash1234
  file://$ENV{HOME}/.local/repo/subdirectory
  https://supercoolhost.info/~supercooldud/subdirectory.git
  https://gitlab.com/supercooldud/subdirectory.git
  https://github.com/supercooldud/subdirectory.git)
```

Voila, an equivalent to Git submodules, but not tying yourself to any specific host. You can specify “master” or some branch for the commit hash, but you can specify a commit hash, which ensures that no amount of maliciousness on any host’s part is going to corrupt your code, if they only have access to the dependencies. You can specify a list of URLs, with the quickest local repositories on top, and the slowest, least reliable repositories on the bottom.

It could work in theory for other versioning systems like SVN, CVS, Mercurial or Darcs, but I only implemented Git so far since I don’t know all those too well. It uses shallow clones by default since Git has good support for that now and it saves on bandwidth and disk space. It does NOT recurse into submodules by default because as we’ve said, git submodules kind of suck. Instead, you can just `add_module` the submodules in your top level CMakeLists.txt file, or fix the code you’re adding to use `add_module` instead of submodules, and get a more robust and certain way to clone those submodules too.

It clones the modules into `${CMAKE_BUILD_DIR}/modules` which for the most part seems to work fine. It probably should analyze the URL to make a destination directory, or name the directory by commit hash, because two projects by the same name can’t be added to the same project. Or at least on conflict it should fall back on saying `projectname` and `projectname-2` or something. I’m not sure it needs to use `${CMAKE_CURRENT_BUILD_DIR}` instead of `${CMAKE_BUILD_DIR}` because having all add_module modules available in a single subdirectory from the top build dir is a really convenient way to keep track of what is being (recursively) required by dependencies in your project. So put that on the TODO list I suppose.

Apparently this is already working in Go: https://blog.golang.org/using-go-modules so I don’t need to be as concerned anymore. Still, isn’t Git supposed to be a _distributed_ revision control system, without needing a holy official central archive that all others can only defer to? Why tie the module name to the place you fetched it from?
