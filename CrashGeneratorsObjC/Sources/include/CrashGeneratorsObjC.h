#import <Foundation/Foundation.h>

FOUNDATION_EXPORT void CrashWithCPPException(void);
FOUNDATION_EXPORT void CrashWithUseAfterFree(void);
FOUNDATION_EXPORT void CrashWithDoubleFree(void);
FOUNDATION_EXPORT void CrashWithStackOverflow(void);
FOUNDATION_EXPORT void CrashWithBufferOverflow(void);

// CrashProbe – Memory access
FOUNDATION_EXPORT void CrashWithGarbagePointerDeref(void);
FOUNDATION_EXPORT void CrashWithWriteToReadOnlyPage(void);
FOUNDATION_EXPORT void CrashWithJumpToNonExecutablePage(void);

// CrashProbe – Bad instruction
FOUNDATION_EXPORT void CrashWithUndefinedInstruction(void);
FOUNDATION_EXPORT void CrashWithPrivilegedInstruction(void);
FOUNDATION_EXPORT void CrashWithBuiltinTrap(void);

// CrashProbe – Stack corruption
FOUNDATION_EXPORT void CrashWithSmashStackTop(void);
FOUNDATION_EXPORT void CrashWithSmashStackBottom(void);
FOUNDATION_EXPORT void CrashWithOverwriteLinkRegister(void);

// CrashProbe – ObjC runtime
FOUNDATION_EXPORT void CrashWithMessageFreedObject(void);
FOUNDATION_EXPORT void CrashWithCorruptObjCRuntime(void);
FOUNDATION_EXPORT void CrashWithObjcMsgSendInvalidISA(void);
FOUNDATION_EXPORT void CrashWithNSLogNonObject(void);

// CrashProbe – C++ exception
FOUNDATION_EXPORT void CrashWithCPPBadAlloc(void);
FOUNDATION_EXPORT void CrashWithCPPStringExceptionHeap(void);
FOUNDATION_EXPORT void CrashWithCPPStringExceptionStack(void);
FOUNDATION_EXPORT void CrashWithCPPConstCharException(void);

// CrashProbe – ObjC exception
FOUNDATION_EXPORT void CrashWithObjCExceptionThrow(void);
FOUNDATION_EXPORT void CrashWithObjCExceptionRaise(void);
FOUNDATION_EXPORT void CrashWithObjCExceptionFromCPP(void);

// CrashProbe – Heap corruption
FOUNDATION_EXPORT void CrashWithCorruptMallocTracking(void);

// CrashProbe – Threading
FOUNDATION_EXPORT void CrashWithPthreadLockHeld(void);
