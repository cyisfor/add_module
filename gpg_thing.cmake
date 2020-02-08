execute_process(
  COMMAND ${A_INPUT}
  env "GNUPGHOME=${A_HOME}"
  gpg
  ${A_INTERACTIVE}
  ${args}
  RESULT_VARIABLE result
  ${A_INPUT_FILE}
  ${A_OUTPUT_VARIABLE})
