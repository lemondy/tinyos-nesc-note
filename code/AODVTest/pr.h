#ifndef MY_PR_H
#define MY_PR_H

#ifdef ENABLE_PR


#ifndef TOSSIM
#include "printf.h"

#define pr(fmt, args...) do { printf(fmt, ##args); printfflush(); } while (0)
#else

#define pr(fmt, args...) dbg("Sim", fmt, ##args)

#endif // TOSSIM

#else

#define pr(fmt, args...) 

#endif // ENABLE_PR


#endif /* PR_H */
