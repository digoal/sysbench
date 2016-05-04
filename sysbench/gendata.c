#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>
#include <stdint.h>
#include <sys/time.h>
uint64_t my_rand(struct random_data * r1, struct random_data * r2)
{
    uint64_t rand_max = 100000000000LL;
    uint64_t result;
    uint32_t u1, u2;
    random_r(r1, &u1);
    random_r(r2, &u2);
    result = (int64_t)u1 * (int64_t)u2;
    result = result % rand_max;
    return result;
}
int main(int argc, char *argv[])
{
    struct timeval tpstart;
    struct random_data r1, r2;
    int i;
    int r;
    int max_value;
    char rand_state1[128];
    char rand_state2[128];
    if (argc !=2)
    {
        printf("Usage: %s <rownums>\n", argv[0]);
        return 1;
    }
    max_value = atoi(argv[1]);
    gettimeofday(&tpstart,NULL);
    memset( &r1, 0, sizeof( r1 ) );
    memset( &r2, 0, sizeof( r2 ) );

    initstate_r(tpstart.tv_usec,rand_state1,sizeof(rand_state1),&r1);
    srandom_r(tpstart.tv_usec, &r1);
    gettimeofday(&tpstart,NULL);
    initstate_r(tpstart.tv_usec,rand_state2,sizeof(rand_state1),&r2);
    srandom_r(tpstart.tv_usec, &r2);
    for (i=1; i<max_value+1; i++)
    {
        r = my_rand(&r1, &r2) % max_value; 
        printf("%d,%d,%011llu-%011llu-%011llu-%011llu-%011llu-%011llu-%011llu-%011llu-%011llu-%011llu,%011llu-%011llu-%011llu-%011llu-%011llu\n",
                i,
                r,
                 my_rand(&r1, &r2),
                 my_rand(&r1, &r2),
                 my_rand(&r1, &r2),
                 my_rand(&r1, &r2),
                 my_rand(&r1, &r2),
                 my_rand(&r1, &r2),
                 my_rand(&r1, &r2),
                 my_rand(&r1, &r2),
                 my_rand(&r1, &r2),
                 my_rand(&r1, &r2),
                 my_rand(&r1, &r2),
                 my_rand(&r1, &r2),
                 my_rand(&r1, &r2),
                 my_rand(&r1, &r2),
                 my_rand(&r1, &r2)
              );
    }
    return 0;
}
