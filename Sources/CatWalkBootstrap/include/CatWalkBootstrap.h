//
//  CatWalkBootstrap.h
//  CatWalk
//

#ifndef CATWALK_BOOTSTRAP_H
#define CATWALK_BOOTSTRAP_H

/// Referenced by `CatWalk.start` so static linking keeps the load-time constructor.
/// Returns whether the constructor ran (always 0 in builds without the inspector).
int catwalk_bootstrap_did_run(void);

#endif
