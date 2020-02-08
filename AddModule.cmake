if(ENV{__ADD_MODULE_INCLUDED__})
  return()
endif()

set(ADD_MODULE_STRICT_VERSION TRUE CACHE BOOL
  "Set this to OFF and add_module will only warn upon detecting a version mismatch instead of erroring out. May be good to disable when debugging deep submodules with inadequate self tests. A better idea would be to write adequate self tests for those submodules.")

set(GPG_HOME "${CMAKE_BINARY_DIR}/gnupg_modules"
  CACHE STRING
  "The GNUPGHOME for trusting keys in CMakeLists.txt")


if(NOT MODULE_DIR)
  get_filename_component(moduledir "modules" ABSOLUTE
	BASE_DIR "${CMAKE_BINARY_DIR}")
  file(MAKE_DIRECTORY "${moduledir}")
  set(MODULE_DIR "${moduledir}"
	CACHE
	FILEPATH "Where modules are located")
  get_filename_component(moduledir "bin_modules" ABSOLUTE
	BASE_DIR "${CMAKE_BINARY_DIR}")
  file(MAKE_DIRECTORY "${moduledir}")
  set(MODULE_BIN_DIR "${moduledir}"
	CACHE
	FILEPATH "Where modules are compiled")
endif(NOT MODULE_DIR)

if(NOT TARGET add_module_derp)
  add_custom_target(add_module_derp)
  set_property(TARGET add_module_derp 
	PROPERTY listdir
	"${CMAKE_CURRENT_LIST_DIR}")
endif()

function (safely_add_subdir source binary)
  # the SUBDIRECTORIES property is useless
  # because even if you add_subdirectory in a different source dir
  # it still errors out, with no way to tell which source dir had the subdir
  get_property(foundit
	TARGET add_module_derp
	PROPERTY "subdir_${source}"
	DEFINED)
  if(foundit)
	return()
  endif()
  message("DEFINEIT")
  define_property(TARGET
	PROPERTY "subdir_${source}"
	BRIEF_DOCS "FU"
	FULL_DOCS "FU")
  
  set_property(TARGET  add_module_derp PROPERTY "subdir_${source}" "")
  add_subdirectory("${source}" "${binary}")
endfunction(safely_add_subdir)

function (add_module_git directory source listfile RESULT commit)
  get_property(prop GLOBAL PROPERTY "add_module_git_${source}" DEFINED)
  if(prop)
	get_property(prop GLOBAL PROPERTY "add_module_git_${source}")
	if(NOT prop STREQUAL commit)
	  message(FATAL_ERROR
		"Need to have the same commit hash for ${directory} ${prop} != ${commit} ${source}")
	else()
	  #message("OK yay got commit ${commit} again")
	endif()
	return()
  endif()
  define_property(GLOBAL PROPERTY "add_module_git_${source}"
	BRIEF_DOCS "no"
	FULL_DOCS "no")
  set_property(GLOBAL PROPERTY "add_module_git_${source}" "${commit}")
  cmake_parse_arguments(PARSE_ARGV 5 GIT
	"NOSHALLOW;RECURSE" "SIGNER" "")
  get_filename_component(dotgit ".git" ABSOLUTE
	BASE_DIR "${source}")
  file(TIMESTAMP "${dotgit}" dotgit)
  if(dotgit)
	# already there yo
	set(temp "${source}")
  else(dotgit)
	get_filename_component(temp "temp" ABSOLUTE
	  BASE_DIR "${MODULE_DIR}")
	file(REMOVE_RECURSE "${temp}")
  endif(dotgit)

  if(NOT GIT_RECURSE)
	set(GIT_RECURSE "")
  else()
	set(GIT_RECURSE "--recurse-submodules")
  endif()

  macro (git)
	execute_process(
	  COMMAND git ${ARGV}
	  WORKING_DIRECTORY "${temp}"
	  RESULT_VARIABLE result)
  endmacro(git)
  if(GIT_SIGNER)
	function (gpg)
	  cmake_parse_arguments(PARSE_ARGV 0 A "INTERACTIVE" "HOME;INPUT;INPUT_FILE;OUTPUT_VARIABLE;OUTPUT_FILE" "")
	  if(A_INPUT)
		set(A_INPUT "${A_INPUT} |")
	  endif()
	  if(A_INTERACTIVE)
		set(A_INTERACTIVE "")
	  else()
		set(A_INTERACTIVE
		  "--batch --with-colons --no-tty --yes")
	  endif()
	  if(A_HOME)
	  else()
		set(A_HOME "${GPG_HOME}")
		file(MAKE_DIRECTORY "${A_HOME}")
	  endif()
	  if(A_INPUT_FILE)
		set(A_INPUT_FILE "INPUT_FILE ${A_INPUT_FILE}")
	  endif()
	  if(A_OUTPUT_VARIABLE)
		set(A_OUTPUT_VARIABLE "OUTPUT_VARIABLE ${A_OUTPUT_VARIABLE}")
	  endif()
	  if(A_OUTPUT_FILE)
		set(A_OUTPUT_FILE "OUTPUT_FILE ${A_OUTPUT_FILE}")
	  endif()
	  # XXX: cmake won't escape the arguments! Now what?
	  # not a problem for gpg specifically though
	  list(JOIN A_UNPARSED_ARGUMENTS " " args)
	  get_property(listdir
		TARGET add_module_derp
		PROPERTY "listdir")	  
	  configure_file("${listdir}/gpg_thing.cmake" "derpthing.cmake")
	  include("${CMAKE_CURRENT_BINARY_DIR}/derpthing.cmake")
	  set(result "${result}" PARENT_SCOPE)
	endfunction(gpg)
	function(gpgorfail)
	  gpg(${ARGV})
	  if(NOT result EQUAL 0)
		message(FATAL_ERROR "(${result}) Couldn't run gpg ${A_INTERACTIVE} ${args}")
	  endif()
	endfunction(gpgorfail)

  endif(GIT_SIGNER)
  if(NOT dotgit)
	file(MAKE_DIRECTORY "${temp}")
	git(init)
	git(config --replace-all advice.detachedHead false)
	git(remote add origin placeholder)
	if(NOT result EQUAL 0)
	  message(FATAL_ERROR "Couldn't init a git repository? ${result}")
	endif()
  endif(NOT dotgit)
  if(GIT_SIGNER)
	set(gpgtemp "${CMAKE_CURRENT_BINARY_DIR}/.temp")
	file(TIMESTAMP "${GPG_HOME}" res)
	if(res)
	else()
	  # set up our module's GNUPG home directory...
	  set(gpgtemphome "${CMAKE_BINARY_DIR}/.tmpgnupg_modules")
	  # ugh... cmake sucks
	  file(MAKE_DIRECTORY "foo${gpgtemphome}")
	  file(MAKE_DIRECTORY "foo${gpgtemphome}/${gpgtemphome}")
	  file(COPY "foo${gpgtemphome}/${gpgtemphome}"
		DESTINATION "."
		DIRECTORY_PERMISSIONS
		OWNER_READ OWNER_WRITE OWNER_EXECUTE)
	  file(REMOVE "foo${gpgtemphome}")
	  # import our home keyring
	  gpgorfail(
		HOME "$ENV{HOME}/.gnupg"
		OUTPUT_FILE "${gpgtemp}" 
		--export)
	  gpgorfail(
		HOME "${gpgtemphome}"
		INPUT_FILE "${gpgtemp}"
		--quiet
		--import)	  
	  file(RENAME "${gpgtemphome}" "${GPG_HOME}")
	endif()
	gpg(--list-keys "${GIT_SIGNER}" OUTPUT_FILE "${gpgtemp}")
	file(STRINGS "${gpgtemp}" lines)
	list(LENGTH lines linelen)
	if(linelen EQUAL 1)
	  message("git signer ${GIT_SIGNER} not found. Need to receive it...")
	  gpg(--recv-key "${GIT_SIGNER}")
	  # set to ultimate trust (for our local module GNUPGHOME)
	  gpg(INPUT "echo ${GIT_SIGNER}:6:"
		--import-ownertrust)
	else()
	  message("git signer ${GIT_SIGNER} found.")
	endif()
	git(config --replace-all merge.verify-signatures true)
  endif(GIT_SIGNER)

  foreach(url IN LISTS GIT_UNPARSED_ARGUMENTS)
	git(remote set-url origin "${url}")
	if(NOT GIT_NOSHALLOW)
	  # https://stackoverflow.com/questions/31278902/how-to-shallow-clone-a-specific-commit-with-depth-1
	  if(result EQUAL 0)
		git(fetch ${GIT_RECURSE} --depth 1 origin "${commit}")
		if(result EQUAL 0)
		  git(checkout FETCH_HEAD)
		endif()
	  endif()
	else(NOT GIT_NOSHALLOW)
	  git(pull ${GIT_RECURSE} origin "${commit}")
	endif(NOT GIT_NOSHALLOW)
	if(result EQUAL 0)
	  git(checkout "${commit}")
	  if(NOT result EQUAL 0)
		message(FATAL_ERROR "Could not checkout commit ${commit} from ${directory}")
	  endif()
	  if(NOT dotgit)
		file(RENAME "${temp}" "${source}")
		file(REMOVE_RECURSE "${temp}")
	  endif(NOT dotgit)
	  set("${RESULT}" TRUE PARENT_SCOPE)
	  return()
	endif(result EQUAL 0)
	if(ADD_MODULE_STRICT_VERSION)
	  message(FATAL_ERROR "URL ${url} failed for GIT ${directory}")
	else()
	  message(WARNING "URL ${url} failed for GIT ${directory}")
	endif()
  endforeach(url in LISTS GIT_UNPARSED_ARGUMENTS)
  message(WARNING
	"Could not clone ${directory} from any of its GIT URIs!")
  set("${RESULT}" FALSE PARENT_SCOPE)
  if(NOT dotgit)
	file(REMOVE_RECURSE "${temp}")
  endif(NOT dotgit)
endfunction(add_module_git)

function (add_module directory)
  # NOT current binary dir
  get_filename_component(source "${directory}" ABSOLUTE
	BASE_DIR "${MODULE_DIR}")
  get_filename_component(bindir "${directory}" ABSOLUTE
	BASE_DIR "${MODULE_BIN_DIR}")  
  get_filename_component(listfile "CMakeLists.txt" ABSOLUTE
	BASE_DIR "${source}")
  # no return here because we have to make sure the correct commit is checked out 
  set(options)
  set(onevalue FUNCTION)
  set(multivalue GIT)
  cmake_parse_arguments(PARSE_ARGV 1 A
	"${options}" "${onevalue}" "${multivalue}")
  if(A_GIT)
	add_module_git("${directory}" "${source}" "${listfile}" RESULT ${A_GIT})
	if(RESULT)
	  file(TIMESTAMP "${listfile}" timestamp)
	  if(timestamp)
	  else(timestamp)
		message(FATAL_ERROR "no listfile found ${directory} ${A_GIT}")
	  endif(timestamp)
	  safely_add_subdir("${source}" "${bindir}")
	  return()
	endif(RESULT)
  endif(A_GIT)
  message(FATAL_ERROR
	"Could not clone ${directory} by any method!")
endfunction(add_module)

set(ENV{__ADD_MODULE_INCLUDED__} 1)
