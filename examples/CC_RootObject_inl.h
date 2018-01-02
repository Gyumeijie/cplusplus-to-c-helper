//
// Copyright 2004 P&P Software GmbH - All Rights Reserved
//
// CC_RootObject_inl.h
//
// Version	1.0
// Date	    11.04.03 
// Author	A. Pasetti (P&P Software)
//
// Change Record:

#ifndef CC_RootObjectINL
#define CC_RootObjectINL

#include "../GeneralInclude/CompilerSwitches.h"
#include "../GeneralInclude/DebugSupport.h"
#include "../GeneralInclude/Constants.h"
#include "../Event/DC_EventRepository.h"

inline DC_EventRepository* CC_RootObject::getEventRepository(void) {
    assert( pEventRepository!=pNULL);
    return pEventRepository;
}

#endif
