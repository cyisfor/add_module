execute_process(
  COMMAND ${A_INPUT}
  ${A_HOME}
  gpg
  ${A_INTERACTIVE}
  ${args}
  RESULT_VARIABLE "${result}"
  ${A_INPUT_FILE}
  ${A_OUTPUT_FILE}
  ${A_OUTPUT_VARIABLE})
