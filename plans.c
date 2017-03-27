#include <stdio.h>
#include <stdlib.h>
#include <hiredis/hiredis.h>

#include "arg.h"


int main(int argc, char *argv[])
{
    fprintf(stdout, "%s: yer here\n", "foo");
    redisContext *c = redisConnect("127.0.0.1", 6379);
    if (c == NULL || c->err) {
        if (c) {
            printf("Error: %s\n", c->errstr);
            // handle error
        } else {
            printf("Can't allocate redis context\n");
        }
    }
    redisCommand(c, "SET foo %s", "nice");
    return 0;
}

