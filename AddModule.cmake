include_guard(GLOBAL)

if(NOT MODULE_DIR)
  get_filename_component(moduledir "modules" ABSOLUTE
	BASE_DIR "${CMAKE_BINARY_DIR}")
  file(MAKE_DIRECTORY "${moduledir}")
  set(MODULE_DIR "${moduledir}"
	CACHE
	FILEPATH "Where modules are located")
  get_filename_component(moduledir "module_bin" ABSOLUTE
	BASE_DIR "${CMAKE_BINARY_DIR}")
  file(MAKE_DIRECTORY "${moduledir}")
  set(MODULE_BIN_DIR "${moduledir}"
	CACHE
	FILEPATH "Where modules are compiled")
endif()

macro (add_module_check directory commit existingfile abs)
  file(TIMESTAMP "${existingfile}" timestamp)
  get_filename_component(bindir "${directory}" ABSOLUTE
	BASE_DIR "${MODULE_BIN_DIR}")
  file(MAKE_DIRECTORY "${bindir}")
  message("going into ${abs}")
  if(timestamp)
	add_subdirectory("${abs}" "${bindir}")  
  endif(timestamp)
endmacro(add_module_check)

function (add_module_git directory abs listfile RESULT commit)
  cmake_parse_arguments(PARSE_ARGV 3 GIT
	"SHALLOW;NORECURSE" "" "URLS")
  get_filename_component(dotgit ".git" ABSOLUTE
	BASE_DIR "${abs}")
  file(TIMESTAMP "${dotgit}" dotgit)
  if(dotgit)
	# already there yo
	set(temp "${abs}")
  else(dotgit)
	get_filename_component(temp "temp" ABSOLUTE
	  BASE_DIR "${MODULE_DIR}")
	file(REMOVE_RECURSE "${temp}")
  endif(dotgit)

  if(GIT_NORECURSE)
	set(GIT_NORECURSE "")
  else()
	set(GIT_NORECURSE "--recurse-submodules")
  endif()

  macro (git)
	execute_process(
	  COMMAND git ${ARGV}
	  WORKING_DIRECTORY "${temp}"
	  RESULT_VARIABLE result)
  endmacro(git)
  if(NOT dotgit)
	file(MAKE_DIRECTORY "${temp}")
	git(init)
	git(config --replace-all advice.detachedHead false)
	git(remote add origin placeholder)
	if(NOT result EQUAL 0)
	  message(FATAL_ERROR "Couldn't init a git repository? ${herp} ${result}")
	endif()
  endif(NOT dotgit)
  foreach(url IN LISTS GIT_URLS)
	git(remote set-url origin "${url}")
	if(GIT_SHALLOW)
	  # https://stackoverflow.com/questions/31278902/how-to-shallow-clone-a-specific-commit-with-depth-1
	  if(result EQUAL 0)
		git(fetch ${GIT_NORECURSE} --depth 1 origin "${commit}")
		if(result EQUAL 0)
		  git(checkout FETCH_HEAD)
		endif()
	  endif()
	else(GIT_SHALLOW)
	  git(pull ${GIT_RECURSE} origin "${commit}")
	endif(GIT_SHALLOW)
	if(result EQUAL 0)
	  git(checkout "${commit}")
	  if(NOT result EQUAL 0)
		message(FATAL_ERROR "Could not checkout commit ${commit} from ${directory}")
	  endif()
	  if(NOT dotgit
		file(RENAME "${temp}" "${abs}")
		file(REMOVE_RECURSE "${temp}")
	  endif(NOT dotgit)
	  set("${RESULT}" TRUE PARENT_SCOPE)
	  return()
	endif(result EQUAL 0)
	message(WARNING "URL ${url} failed for GIT ${directory}")
  endforeach(url in LISTS urls)
  message(WARNING
	"Could not clone ${directory} from any of its GIT URIs!")
  set("${RESULT}" FALSE PARENT_SCOPE)
  if(NOT dotgit)
	file(REMOVE_RECURSE "${temp}")
  endif(NOT dotgit)
endfunction(add_module_git)

function (add_module directory)
  # NOT current binary dir
  get_filename_component(abs "${directory}" ABSOLUTE
	BASE_DIR "${MODULE_DIR}")
  get_filename_component(listfile "CMakeLists.txt" ABSOLUTE
	BASE_DIR "${abs}")
  # no return here because we have to make sure the correct commit is checked out 
  set(options)
  set(onevalue FUNCTION)
  set(multivalue GIT)
  cmake_parse_arguments(PARSE_ARGV 1 A
	"${options}" "${onevalue}" "${multivalue}")
  if(A_GIT)
	add_module_git("${directory}" "${abs}" "${listfile}" RESULT ${A_GIT})
	if(RESULT)
	  add_module_check("${directory}" "${commit}" "${listfile}" "${abs}")
	  if(timestamp)
		return()
	  endif()
	endif()
  endif(A_GIT)
  message(FATAL_ERROR
	"Could not clone ${directory} by any method!")
endfunction(add_module)
