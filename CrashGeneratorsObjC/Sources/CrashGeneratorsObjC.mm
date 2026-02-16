#import "CrashGeneratorsObjC.h"
#import <exception>
#import <new>
#import <string>
#import <sys/mman.h>
#import <malloc/malloc.h>
#import <mach/mach.h>
#import <pthread.h>
#import <objc/runtime.h>

// ─── Original crash types ───────────────────────────────────────────

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

// ─── CrashProbe: Memory access ─────────────────────────────────────

void CrashWithGarbagePointerDeref(void)
{
    uintptr_t addr = 0xDEADBEEF;
    int *ptr = (int *)addr;
    *ptr = 42;
}

void CrashWithWriteToReadOnlyPage(void)
{
    void *page = mmap(NULL, (size_t)vm_page_size, PROT_READ,
                      MAP_ANON | MAP_PRIVATE, -1, 0);
    if (page == MAP_FAILED) { abort(); }
    char *p = (char *)page;
    *p = 'X'; // SIGBUS — write to read-only page
}

void CrashWithJumpToNonExecutablePage(void)
{
    void *page = mmap(NULL, (size_t)vm_page_size, PROT_READ | PROT_WRITE,
                      MAP_ANON | MAP_PRIVATE, -1, 0);
    if (page == MAP_FAILED) { abort(); }
    // Write a return instruction then jump into the non-executable page
    memset(page, 0xC3, (size_t)vm_page_size);
    typedef void (*fn_t)(void);
    fn_t fn = (fn_t)page;
    fn();
}

// ─── CrashProbe: Bad instruction ───────────────────────────────────

void CrashWithUndefinedInstruction(void)
{
#if __arm64__
    __asm__ volatile(".word 0x00000000"); // UDF #0
#elif __x86_64__
    __asm__ volatile("ud2");
#else
    abort();
#endif
}

void CrashWithPrivilegedInstruction(void)
{
#if __arm64__
    __asm__ volatile("msr VBAR_EL1, x0"); // EL1 register from EL0
#elif __x86_64__
    __asm__ volatile("hlt");
#else
    abort();
#endif
}

void CrashWithBuiltinTrap(void)
{
    __builtin_trap();
}

// ─── CrashProbe: Stack corruption ──────────────────────────────────

__attribute__((noinline))
void CrashWithSmashStackTop(void)
{
    char buf[16];
    memset(buf, 0x41, 256); // overwrite past the top of the stack frame
}

__attribute__((noinline))
void CrashWithSmashStackBottom(void)
{
    char buf[16];
    memset(buf - 256, 0x42, 256); // overwrite below the stack frame
}

__attribute__((noinline))
void CrashWithOverwriteLinkRegister(void)
{
#if __arm64__
    __asm__ volatile(
        "mov x30, #0\n" // zero the link register (return address)
        "ret\n"
    );
#elif __x86_64__
    __asm__ volatile(
        "movq $0, (%%rsp)\n" // overwrite return address on stack
        "ret\n"
        ::: "memory"
    );
#else
    abort();
#endif
}

// ─── CrashProbe: ObjC runtime ──────────────────────────────────────

void CrashWithMessageFreedObject(void)
{
    NSObject * __unsafe_unretained obj;
    @autoreleasepool {
        NSObject *temp = [[NSObject alloc] init];
        obj = temp;
    }
    // obj has been deallocated; messaging it should crash
    [obj description];
    abort(); // fallback
}

void CrashWithCorruptObjCRuntime(void)
{
    NSObject *obj = [[NSObject alloc] init];
    // Corrupt the isa pointer
    memset((__bridge void *)obj, 0xFF, 16);
    [obj description];
    abort(); // fallback
}

void CrashWithObjcMsgSendInvalidISA(void)
{
    // Create an object with a completely invalid isa pointer
    void *fakeObj[2] = { (void *)0xDEADBEEF, NULL };
    id obj = (__bridge id)(void *)fakeObj;
    [obj description];
    abort(); // fallback
}

void CrashWithNSLogNonObject(void)
{
    // Pass a non-object as %@ — triggers objc_msgSend on garbage
    uintptr_t garbage = 0xDEADBEEF;
    NSLog(@"%@", (__bridge id)(void *)garbage);
    abort(); // fallback
}

// ─── CrashProbe: C++ exception ─────────────────────────────────────

void CrashWithCPPBadAlloc(void)
{
    throw std::bad_alloc();
}

void CrashWithCPPStringExceptionHeap(void)
{
    // Heap-allocated std::string as exception payload
    std::string msg("Intentional CI crash: C++ string exception (heap)");
    throw msg;
}

void CrashWithCPPStringExceptionStack(void)
{
    // Throw a string built on the stack
    throw std::string("Intentional CI crash: C++ string exception (stack)");
}

void CrashWithCPPConstCharException(void)
{
    throw "Intentional CI crash: const char* exception";
}

// ─── CrashProbe: ObjC exception ────────────────────────────────────

void CrashWithObjCExceptionThrow(void)
{
    @throw [NSException exceptionWithName:@"CIAutomationCrash"
                                   reason:@"Intentional CI crash: ObjC exception throw"
                                 userInfo:nil];
}

void CrashWithObjCExceptionRaise(void)
{
    [[NSException exceptionWithName:@"CIAutomationCrash"
                             reason:@"Intentional CI crash: ObjC exception raise"
                           userInfo:nil] raise];
}

void CrashWithObjCExceptionFromCPP(void)
{
    // C++ throw of an NSException — exercises the ObjC/C++ interop path
    NSException *exc = [NSException exceptionWithName:@"CIAutomationCrash"
                                               reason:@"Intentional CI crash: ObjC exception from C++"
                                             userInfo:nil];
    throw exc;
}

// ─── CrashProbe: Heap corruption ───────────────────────────────────

void CrashWithCorruptMallocTracking(void)
{
    char *buf = (char *)malloc(64);
    // Write before the allocation, corrupting malloc's internal tracking
    memset(buf - 16, 0xFF, 16);
    free(buf);
    abort(); // fallback
}

// ─── CrashProbe: Threading ─────────────────────────────────────────

void CrashWithPthreadLockHeld(void)
{
    static pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;
    pthread_mutex_lock(&mutex);

    // Destroy a locked mutex — undefined behaviour, crashes on most platforms
    pthread_mutex_destroy(&mutex);

    // If the above didn't crash, force the issue by crashing the thread
    abort();
}
