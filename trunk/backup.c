
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#define ZIP_USER_NEXT_TIME 30*60
#define ZIP_OTHER_NEXT_TIME 24*60*60

static char random_char_or_number()
{
    switch ( rand()%3 ) {
        case 0:
            return 48 + rand()%10; /* "0" ~ "9" */
            break;
        case 1:
            return 65 + rand()%26; /* "A" ~ "Z" */
            break;
        case 2:
            return 97 + rand()%26; /* "a" ~ "z" */
            break;
    }
    return '0';
}

static void fill_random_chars(char* str, int size)
{
    int i;
    for( i = 0; i < size; ++i )
        str[i] = random_char_or_number();
    str[i] = '\0';
}

static void call_zip_routine(char* id, char* pkgname, char uflag, int nexttime, int test)
{
    char buf[80], fname[80], userid[13] = "linjack";
    FILE* record;
    sprintf(fname, "home/%c/%s/nextpacktime.log", userid[0], userid);

    record = fopen(fname, "w");
    fprintf(record, "%lu\n", (unsigned long)(time(NULL) + nexttime));
    if( test )
        sprintf(buf, "ruby bbs2html.rb %s %s %c -test", id, pkgname, uflag);
    else
        sprintf(buf, "ruby bbs2html.rb %s %s %c", id, pkgname, uflag);
    system(buf);
    fclose(record);

    printf("You can download the pack at: http://www.ttsh.tp.edu.tw/bbs/%s.zip\n", pkgname);
}

static int do_zip(char id[13], int pack_other)
{
    static unsigned long nextpacktime = 0;
    FILE* record = 0;
    char buf[80], *pkgname, userid[13] = "linjack";

    pkgname = (char*)malloc(sizeof(char)*7);
    fill_random_chars(pkgname, 6);

    sprintf(buf, "home/%c/%s/nextpacktime.log", userid[0], userid);

    /* no record, can do backup and then write log. */
    if( (record = fopen(buf,"r")) == NULL ) {
        if( pack_other )
            call_zip_routine(id, pkgname, 'b', ZIP_OTHER_NEXT_TIME, 0);
        else
            call_zip_routine(id, pkgname, 'u', ZIP_USER_NEXT_TIME, 0);
    } else { /* have record, need to compare time elapsed. */
        fscanf(record, "%lu", &nextpacktime);
        fclose(record);
        int to_next_time = nextpacktime - time(NULL);
        if( to_next_time > 0 /* and if you're not admin */) /* you can't pack yet */
            printf("You still have to wait %d min(s) %d sec(s).\n", to_next_time/60, to_next_time%60);
        else { /* ok, you can pack */
            if( pack_other )
                call_zip_routine(id, pkgname, 'b', ZIP_OTHER_NEXT_TIME, 0);
            else
                call_zip_routine(id, pkgname, 'u', ZIP_USER_NEXT_TIME, 0);
        }
    }
    free(pkgname);
    return 0;
}

int main()
{
    srand(time(NULL));
    do_zip("chance", 0);
    return 0;
}
