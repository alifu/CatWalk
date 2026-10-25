//
//  CatWalkBootstrap.c
//  CatWalk
//
//  Installs session capture when the binary loads, before `main` and before any session the
//  app creates in `App.init` or a static initialiser. Capture stays off until `CatWalk.start`.
//

#include "CatWalkBootstrap.h"

#ifdef CATWALK_ENABLED

/// Defined in Swift (`CWBootstrap.swift`) with `@_cdecl`.
extern void catwalk_bootstrap(void);

static int didRun = 0;

__attribute__((constructor))
static void catwalk_bootstrap_constructor(void) {
    catwalk_bootstrap();
    didRun = 1;
}

int catwalk_bootstrap_did_run(void) {
    return didRun;
}

#else

int catwalk_bootstrap_did_run(void) {
    return 0;
}

#endif
