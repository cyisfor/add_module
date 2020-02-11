set(GNUPG_HOME "${CMAKE_BINARY_DIR}/gnupg"
  CACHE PATH
  "The automatic repository home for gnupg")

set(_GNUPG_CMAKE_SUCKS "${CMAKE_CURRENT_LIST_DIR}")

if(NOT TARGET _cmake_sux_gpg)
  add_custom_target(_cmake_sux_gpg)
  define_property(TARGET
	PROPERTY checked_signers
	BRIEF_DOCS "Signers we already checked to exist"
	FULL_DOCS "natch")
endif()

function (gpg result)
  cmake_parse_arguments(PARSE_ARGV 1 A "INTERACTIVE;NOHOME" "HOME;INPUT;INPUT_FILE;OUTPUT_VARIABLE;OUTPUT_FILE" "")
  if(A_INPUT)
	# input dynamically as a stdin pipe to gpg
	set(A_INPUT "${A_INPUT} |")
  endif()
  if(A_INTERACTIVE)
	set(A_INTERACTIVE "")
  else()
	set(A_INTERACTIVE
	  "--batch --with-colons --no-tty --yes")
  endif()
  if(A_NOHOME)
	set(A_HOME "")
  else()
	if(A_HOME)
	else()
	  set(A_HOME "${GNUPG_HOME}")
	endif()
	file(MAKE_DIRECTORY "${A_HOME}")
	set(A_HOME "env GNUPGHOME=\"${A_HOME}\"")
  endif(A_NOHOME)
  
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
  # not a problem for our use of gpg specifically though
  list(JOIN A_UNPARSED_ARGUMENTS " " args)

  function (checkdir)
	file(TIMESTAMP "${GNUPG_HOME}" res)
	if(res)
	else()
	  file(RELATIVE_PATH gpgtemphome "${GNUPG_HOME}" ".temphome")
	  # ugh... cmake sucks
	  file(MAKE_DIRECTORY "foo${gpgtemphome}")
	  file(MAKE_DIRECTORY "foo${gpgtemphome}/${gpgtemphome}")
	  file(COPY "foo${gpgtemphome}/${gpgtemphome}"
		DESTINATION "."
		DIRECTORY_PERMISSIONS
		OWNER_READ OWNER_WRITE OWNER_EXECUTE)
	  file(REMOVE "foo${gpgtemphome}")
	  # ...
	  file(RENAME "${gpgtemphome}" "${GPG_HOME}")
	endif()
	set(ENV{GNUPGHOME} "${GNUPG_HOME}")
  endfunction(checkdir)
  checkdir()
  
  configure_file("${_GNUPG_CMAKE_SUCKS}/gpg_thing.cmake" "derpthing.cmake")
  # this is the ONLY WAY to do eval in cmake, which hardcodes keywords of execute_program
  include("${CMAKE_CURRENT_BINARY_DIR}/derpthing.cmake")
  set("${result}" "${result}" PARENT_SCOPE)
endfunction(gpg)

function(gpgorfail)
  gpg(result ${ARGV})
  if(NOT result EQUAL 0)
	message(FATAL_ERROR "(${result}) Couldn't run gpg ${ARGV}")
  endif()
endfunction(gpgorfail)

function(gpg_parse_signer gpgtemp result)
  file(STRINGS "${gpgtemp}" lines)
  list(LENGTH lines linelen)
  if(linelen EQUAL 1)
	set("${result}" TRUE PARENT_SCOPE)
  else()
	set("${result}" FALSE PARENT_SCOPE)
  endif()
endfunction(gpg_found_signer)

function(gpg_check_signer signer)
  get_property(checked TARGET _cmake_sux_gpg
	PROPERTY checked_signers)
  list(FIND checked "${signer}" result)
  if(NOT result EQUAL -1)
	return()
  endif()
  file(RELATIVE_PATH gpgtemp "${GNUPG_HOME}" ".temp")
  gpg(result --list-keys "${signer}" OUTPUT_VARIABLE ignore)
  if(result EQUAL 0)
	message("git signer ${signer} found.")
  else()
	message("git signer ${signer} not found. Can it be imported from global default?")
	gpg(result --export "${signer}" NOHOME OUTPUT_FILE "${gpgtemp}")
	if(RESULT EQUAL 0)
	  # need import
	  gpgorfail(--import "${gpgtemp}")
	else()
	  message("nope. trying to receive it...")
	  gpgorfail(--recv-key "${signer}")
	endif()
	list(APPEND checked "${signer}")
	set_property(checked TARGET _cmake_sux_gpg
	  PROPERTY checked_signers "${checked}")
  endif()
  # set to ultimate trust (for our local module GNUPGHOME)
  gpg(INPUT "echo ${signer}:6:"
	--import-ownertrust)
endfunction(gpg_check_signer)

