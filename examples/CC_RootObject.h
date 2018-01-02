//
// Copyright 2004 P&P Software GmbH - All Rights Reserved
//
// CC_RootObject.h
//
// Version	1.0
// Date	    18.04.03 
// Author	A. Pasetti (P&P Software)
//
// Change Record:

#ifndef CC_RootObjectH
#define CC_RootObjectH

#include "../GeneralInclude/ForwardDeclarations.h"
#include "../GeneralInclude/BasicTypes.h"

/** 
* Base class from which most framework classes are - directly or indirectly -
* derived.
* This class defines four attributes and four services that are made available to
* its children classes.
* The attributes are: <ul>
* <li>The instance identifier,</li>
* <li>The class identifier,</li>
* <li>The system event repository,</li>
* <li>The system data pool, and</li>
* <li>The system parameter database.</li>
* </ul>
* The <i>instance identifier</i> is an integer that uniquely identifies each
* object instantiated from this class or its subclasses.
* The instance identifier is automatically assigned by the
* <code>CC_RootObject</code> constructor when a new instance of this class
* is created. It can be read but cannot be changed after an object has
* been created.
* <p>
* The <i>class identifier</i> is an integer that uniquely identifies each
* class derived from <code>CC_RootObject</code>.
* It is useful during debugging and could be used to implement a simple form of
* run-time type identification.
* The class identifier should be set during the application instantiation
* phase and it is intended never to be changed afterwards.
* Only concrete classes are endowed with a class identifier.
* <p>
* The <i>system data pool</i> is an instance of class <code>DataPool</code> that
* is implemented as a static plug-in component for class <code>CC_RootObject</code>. 
* In general, applications instantiated
* from the OBS Framework should have only one data pool component. The 
* <code>CC_RootObject</code> class makes this single data pool instance
* globally accessible to all OBS Framework classes.
* <p>
* The <i>system event repository</i> is an instance of class <code>DC_EventRepository</code> that
* is implemented as a static plug-in component for class <code>CC_RootObject</code>. 
* In general, applications instantiated
* from the OBS Framework should use only one event repository. The 
* <code>CC_RootObject</code> class makes this single event repository instance
* globally accessible to all OBS Framework classes.
* <p>
* The <i>system parameter database</i> is an instance of class <code>ParameterDatabase</code> that
* is implemented as a static plug-in component for class <code>CC_RootObject</code>. 
* In general, applications instantiated
* from the OBS Framework should have only one parameter database component. The 
* <code>CC_RootObject</code> class makes this single parameter database instance
* globally accessible to all OBS Framework classes.
* <p>
* The services implemented by the <code>CC_RootObject</code> class are: <ul>
* <li>a object configuration check service,</li>
* <li>a system configuration check service, and</li>
* <li>a tracing service.</li>
* </ul>
* The <i>object configuration check service</i> allows an external entity to
* ask an object instantiated from a class derived from 
* <CODE>CC_RootObject</CODE> to check whether it is
* configured.
* The term <i>configuration</i> is used to designate the operations that are
* performed on an object during the
* application initialization phase to prepare it to perform its allotted
* task during the application operational phase.
* Generally speaking, an object is configured if all its plug-in
* objects have been loaded and if all its internal data structures have been
* created and initialized.
* <p>
* The <i>system configuration check service</i> allows an external entity to
* verify whether all objects instantiated from a class derived from 
* <CODE>CC_RootObject</CODE> are configured.
* The <CODE>CC_RootObject</CODE> class internally defines a static data
* structure that holds references to all objects that
* have been instantiated from its subclasses.
* This data structure is called the <i>system list</i>.
* The system list data structure is loaded by the <CODE>RootObject</CODE>
* constructor: every time a new object is created, its
* reference is loaded into the data structure.
* The system configuration check service goes through the objects in the
* system list data structure and performs a
* configuration check on each one of them.
* If any of the objects in the system list reports: "not
* configured", then the system configuration
* service reports: "system not configured".
* The system configuration check should be performed at the end of the
* framework instantiation phase to
* confirm the correctness of the instantiation procedure.
* <p>
* The <i>tracing service</i> allows an object instantiated from a class derived from 
* <CODE>CC_RootObject</CODE> to ask for a trace
* signal to be generated.
* The requesting object only has to specify an identifier defining the
* content of the trace signal.
* All other operations related to the sending of the trace signal are handled 
* by a static plug-in object of type <code>Tracer</code>.
* Two types of tracing signals can be generated: synch trace and
* and packet trace.
* The presence of this service in the root class means that all framework
* objects have easy access to the tracing
* service and can easily ask for trace signals to be sent to an external
* test set-up.
* @todo change the name of isObjectConfigured to isConfigured
* @todo fix the policy for inline methods. Currently, all header files that define
* inline methods include the corresponding "_inl" file. This should make it 
* unnecessary for the "_inl" file to be included by the body files. This must be checked
* on the ERC32 simulator. If confirmed, all inclusions of "_inl" files in body
* files should be removed.
* @see DC_EventRepository
* @see DataPool
* @see ParameterDatabase
* @see Tracer
* @author Alessandro Pasetti (P&P Software GmbH)
* @version 1.0
* @ingroup Base
*/
class CC_RootObject {

  private:
     TD_InstanceId instanceId;
     TD_ClassId classId;
   /**
    * Private copy constructor that prevents the copy constructor of this
    * and derived classes (ie most framework classes) from being used. 
    * Use of the copy constructor is judged unsafe and this helps making
    * its accidental use unlikely.
    */
    CC_RootObject(const CC_RootObject& v);

   /**
    * Private asssignment operator that prevents the assignment operator of this
    * and derived classes (ie most framework classes) from being used. 
    * Assignment of objects is judged unsafe and this helps making
    * its accidental use unlikely.
    */
    CC_RootObject& operator= (const CC_RootObject& v);

  public:
   /**
    * Set the instance identifier and loads the newly created object in the
    * system list.
    * A static counter is maintained that is incremented by one every time
    * this constructor is called.
    * The value of this static counter becomes the instance identifier of
    * the newly created object.
    * The class identifier is initialized to an illegal value to signify
    * that the object is not yet
    * configured.
    * The newly created object is loaded into the system list data
    * structure.
    * Thus, a pseudo-code implementation for the constructor is as follows:<PRE>
    *   objectCounter++;          // static counter initialized to BASE_INSTANCE_ID
    *   instanceId=objectCounter;
    *   systemList[i]=this;
    *   classId=. . .;            // initialize class ID to an illegal value
    * </PRE>
    * This constructor will only execute correctly after the size of the system
    * list has been initialized.
    * @see #setSystemListSize
    */
    CC_RootObject(void);

   /**
    * Implement the object configuration check service.
    * The method returns true if the object is correctly configured.
    * A <CODE>RootObject</CODE> is configured if: <ul>
    * <li>the event repository has been loaded</li>
    * <li>the parameter database has been loaded</li>
    * <li>the data pool has been loaded</li>
    * <li>the tracer has been loaded</li>
    * <li>the class identifier has a legal value</li>
    * </ul>
    * The configuration check is class-specific and derived classes may have
    * to provide their own implementation.
    * Derived classes should however provide only incremental
    * implementations.
    * Consider for instance a class B that is derived from a class A.
    * The implementation of <CODE>isConfigured</CODE> for class B should be
    * as follows:<PRE>
    *   bool isConfigured() {
    *   if (!super.isConfigured())
    *           return false;
    *   . . .  // perform configuration checks specific to class A
    *   } </PRE>
    * In this way, each class benefits from the implementation of its super
    * class.
    * @return true if the object is configured, false otherwise.
    */
    const virtual bool isObjectConfigured(void);

   /**
    * Implement the system configuration check service.
    * The method returns true if the system is correctly configured.
    * The system is configured if all the objects instantiated from
    * this class or its subclasses created up to
    * the time the method is called
    * are configured (i.e. if their <code>isObjectConfigured</code> 
    * method returns true).
    * Thus, a pseudo-code implementation of this method is: <PRE>
    *   for (int i=0; i smaller than NumberOfCreatedObjects; i++)
    *   if (!systemList[i].isObjectConfigured())
    *           return false;
    *   return true;   </PRE>
    * where <CODE>systemList</CODE> holds the list of framework objects
    * created to date.
    * <p>
    * This is a static method because the system list data structure upon
    * which it acts is a static structure.
    * <p>
    * @return true if the system is configured, false otherwise.
    */
    static bool isSystemConfigured(void);

   /**
    * Return the instance identifier of an object.
    * The instance identifier is defined when an object is created and
    * cannot be altered afterwards.
    */
    TD_InstanceId getInstanceId(void) const;

   /**
    * Return the class identifier of an object.
    * The class identifier is defined when an object is initially configured 
    * and should not be altered afterwards.
    */
    TD_ClassId getClassId(void) const;

   /**
    * Set the size of the system list representing the maximum number of
    * objects that can be instantiated
    * from class <CODE>RootObject</CODE> and its derived classes.
    * The <CODE>RootObject</CODE> class maintains an internal data structure
    * - the system list - where all created
    * instances of this and derived classes are held.
    * This method causes memory for this data structure to be allocated and
    * the data structure to be
    * initialized.
    * <p>
    * This is a static method because it initializes a data structure - the
    * system list - that is static.
    * <p>
    * This is an initialization method.
    * It should be called before any object of type <CODE>RootObject</CODE>
    * is instantiated. It should not be called more than once.
    * @param systemListSize the maximum number of framework objects that can
    * be instantiated in the
    * application
    */
    static void setSystemListSize(TD_InstanceId systemListSize);

   /**
    * Return the size of the system list representing the maximum number of
    * objects that can be instantiated
    * from class <CODE>RootObject</CODE> and its derived classes.
    * <p>
    * @see #setSystemListSize
    * @return systemListSize the system list size
    */
    static TD_InstanceId getSystemListSize(void);

   /**
    * Set the class identifier of an object.
    * The class identifier should be set when the application is
    * configured and never changed afterwards.
    * <p>
    * This is an initialization method.
    * <p>
    * @param classId the class identifier of the class from which the object
    * is instantiated
    */
    void setClassId(TD_ClassId classId);

   /**
    * Setter method for the event repository plug-in component.
    * The event repository thus loaded is used to store the event reports
    * created with the event reporting service.
    * This method is static to ensure that all event reports created by
    * framework objects are sent to the
    * same event repository.
    */
    static void setEventRepository(DC_EventRepository* pEventRepository);

   /**
    * Getter method for the event repository plug-in component.
    */
    inline static DC_EventRepository* getEventRepository(void);

   /**
    * Setter method for the system parameter database.
    */
    static void setParameterDatabase(ParameterDatabase* pDatabase);

   /**
    * Getter method for the system parameter database.
    */
    static ParameterDatabase* getParameterDatabase(void);

   /**
    * Setter method for the system data pool.
    */
    static void setDataPool(DataPool* pDataPool);

   /**
    * Getter method for the system data pool.
    */
    static DataPool* getDataPool(void);

   /**
    * Load the tracer plug-in object.
    * The tracer thus loaded is used to implement the tracing service.
    * This method is static because all tracing signals are routed through
    * the same tracing interface
    */
    static void setTracer(Tracer* pTracer);

   /**
    * Getter method for the tracer plug-in.
    */
    static Tracer* getTracer(void);

   /**
    * Implement the synch tracing service offered by the root class to all
    * its children classes.
    * When an object needs to send a synch trace signal, it calls this
    * method and passes to it the identifier of
    * the trace signal.
    * The sending of the signal is internally handled by the tracer plug-in
    * object.
    * Thus, a pseudo-code implementation for this method is as follows:
    * <PRE>
    *   tracer.sendSynchTrace(traceId)  </PRE>
    * where <CODE>tracer</CODE> is the tracer plug-in object.
    * <p>
    * @see #setTracer
    * @see Tracer
    * @param traceId identifier of the synch trace signal
    */
    static void synchTrace(TD_TraceItem traceId);

   /**
    * Implement the packet tracing service offered by the root class to all
    * its children classes.
    * When an object needs to send a packet trace signal, it calls this
    * method and passes to it the tracer
    * packet data.
    * The sending of the signal is internally handled by the tracer plug-in
    * object.
    * Thus, a pseudo-code implementation for this method is as follows:
    * <PRE>
    *   tracer.sendPacketTrace(n,traceData)  </PRE>
    * where <CODE>tracer</CODE> is the tracer plug-in object.
    * <p>
    * @see #setTracer
    * @see Tracer
    * @param n number of trace data elements
    * @param traceData array of trace data
    */
    static void packetTrace(unsigned int n, TD_TraceItem traceData[]);

  protected:

    /**
     * Dummy class destructor that causes an assert violation
     * and returns without taking any action.
     * In order to eliminate the danger of dangling pointers and to make
     * memory management safer, the framework adopts a coding rule that prescribes that
     * no instances of framework classes can ever be destroyed (either on the heap
     * or on the stack). Making the destructor of the root class of the framework
     * class tree protected helps detect some violations of this rule statically
     * at compile time. More specifically, it ensures that no instances of
     * class <code>CC_RootObject</code> or its subclasses are ever destroyed
     * outside the <code>CC_RootObject</code> class tree.
     * <p>
     * Subclasses that are intended to be final, should declare a private
     * destructor. This effectively prevents them from being subclassed.
     */
     ~CC_RootObject(void);

};

#include "CC_RootObject_inl.h"

#endif


