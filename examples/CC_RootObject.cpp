//
// Copyright 2004 P&P Software GmbH - All Rights Reserved
//
// CC_RootObject.cpp
//
// Version	1.0
// Date		18.04.03 
// Author	A. Pasetti (P&P Software)
//
// Change Record:

#include "../GeneralInclude/CompilerSwitches.h"
#include "../GeneralInclude/DebugSupport.h"
#include "../GeneralInclude/ClassId.h"
#include "../GeneralInclude/Constants.h"
#include "../Event/DC_EventRepository.h"
#include "../System/Tracer.h"
#include "CC_RootObject.h"

CC_RootObject& CC_RootObject::operator= (const CC_RootObject& v) {
  assert ( false );
  return *this;
}

CC_RootObject::ddCC_RootObject(void) {
  assert( false );
  return;
}


CC_RootObject::CC_RootObject(void) {
  assert(pSystemList != pNULL);
  assert(instanceCounter < getSystemListSize());

  instanceId = instanceCounter;
  setClassId(ID_ROOTOBJECT);

  // register newly created object in the system list.
  if ( instanceCounter < getSystemListSize() ) {
     pSystemList[instanceCounter] = this;
     instanceCounter++;
  }
}

CC_RootObject::CC_RootObject(const CC_RootObject& v) {
  assert( false );
  return;
}


bool CC_RootObject::isObjectConfigured(void) {
  return (pEventRepository!=pNULL && pTracer!=pNULL &&
          pSystemList!=pNULL && pDataPool!=pNULL && pParameterDatabase!=pNULL);
}

bool CC_RootObject::isSystemConfigured(void) {
  for (TD_InstanceId i=0; i<instanceCounter; i++)
     if ( !pSystemList[i]->isObjectConfigured() )
        return NOT_CONFIGURED;
  return CONFIGURED;
}

TD_InstanceId CC_RootObject::getInstanceId(void) const {
  return instanceId;
}

TD_ClassId CC_RootObject::getClassId(void) const {
  return classId;
}

void CC_RootObject::setSystemListSize(TD_InstanceId sysListSize) {
  assert(pSystemList == pNULL);

  systemListSize = sysListSize;
  pSystemList = new CC_RootObject*[systemListSize];
  for (TD_InstanceId i=0; i<systemListSize; i++)
        pSystemList[i] = pNULL;
}

TD_InstanceId CC_RootObject::getSystemListSize(void) {
  return systemListSize;
}

void CC_RootObject::setClassId(TD_ClassId classId) {
  this->classId = classId;
}

void CC_RootObject::setEventRepository(DC_EventRepository* pEventRep) {
  assert( pEventRep != pNULL );
  pEventRepository = pEventRep;
}

void CC_RootObject::setParameterDatabase(ParameterDatabase* pDatabase) {
  assert( pDatabase != pNULL );
  pParameterDatabase = pDatabase;
}

ParameterDatabase* CC_RootObject::getParameterDatabase(void) {
  assert( pParameterDatabase != pNULL );
  return pParameterDatabase;
}

void CC_RootObject::setDataPool(DataPool* pPool) {
  assert( pPool != pNULL );
  pDataPool = pPool;
}

DataPool* CC_RootObject::getDataPool(void) {
  assert( pDataPool != pNULL );
  return pDataPool;
}

void CC_RootObject::setTracer(Tracer* pTrace) {
  assert( pTrace != pNULL );
  pTracer = pTrace;
}

Tracer* CC_RootObject::getTracer(void) {
  assert( pTracer != pNULL );
  return pTracer;
}

void CC_RootObject::packetTrace(unsigned int n, TD_TraceItem traceData[]) {
   assert( (pTracer != pNULL) && (traceData != pNULL) );
   pTracer->sendPacketTrace(n,traceData);
}

void CC_RootObject::synchTrace(TD_TraceItem traceId) {
   assert( pTracer != pNULL );
   pTracer->sendSynchTrace(traceId);
}


