#include "mystring.h"

#include <sqlite3.h>

#include <stdio.h> // more generic includes should go lower! >:(

int main(int argc, char *argv[])
{
    fwrite(LITLEN("Do cool stuff.\n"), 1, stdout);
    return 0;
}
