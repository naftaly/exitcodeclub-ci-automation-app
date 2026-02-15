#import "CrashGeneratorsObjC.h"
#import <exception>

class kaboom: std::exception {
};

void CrashWithCPPException(void)
{
    throw kaboom();
}

void CrashWithUseAfterFree(void)
{
    char *buf = (char *)malloc(100);
    free(buf);
    buf[0] = 'A';
}

void CrashWithDoubleFree(void)
{
    char *buf = (char *)malloc(100);
    free(buf);
    free(buf);
}

void CrashWithBufferOverflow(void)
{
    char buf[10];
    buf[50] = 'X';
}

void CrashWithStackOverflow(void)
{
    CrashWithStackOverflow();
}
