#include "mystring.h"
#include <sqlite3.h>

int main(int argc, char *argv[])
{
    fwrite(LITLEN("Do cool stuff.\n"), 1, stdout);
    return 0;
}
