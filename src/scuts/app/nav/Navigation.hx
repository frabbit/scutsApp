package scuts.app.nav;


//import scuts.core.macros.Lazy;


import haxe.ds.IntMap;
import scuts.core.debug.Assert;

using scuts.reactive.Behaviours;
import scuts.core.Unit;
import scuts.Scuts;

using scuts.core.Functions;
using scuts.core.Options;
using scuts.core.Iterables;
using scuts.core.Arrays;
using scuts.core.Promises;





typedef Handler<NT,X,Y> = { interested : NT->NT->Option<X>, run:X->PromiseD<Y> };

typedef Interceptor<NT,X> = Handler<NT, X, Bool>;

private class Bond 
{
  var enable:Void->Void;
  var disable:Void->Void;
  
  var destroyed:Bool;
  var enabled:Bool;
  
  public function new (enable, disable) 
  {
    this.enable = enable;
    this.disable = disable;
    destroyed = false;
    enabled = true;
  }
  
  public function mute () {
    if (destroyed) throw "Already destroyed";
    setEnabled(false);
    return this;
  }
  
  public function unmute () {
    if (destroyed) throw "Already destroyed";
    setEnabled(true);
    return this;
  }
  
  private function setEnabled (b:Bool) {
    if (!destroyed && b != enabled) {
      enabled = b;
      if (b)
        enable();
      else 
        disable();
    }
    
  }
  
  public function destroy () {
    if (destroyed) throw "Already destroyed";
    
    if (enabled) disable();
    enable = null;
    disable = null;
    destroyed = true;
   
  }
  
  
}

class Navigation <NS, Phase> 
{
  
  
  
  public var current (default, null): Behaviour<NS>;
  public var transition (default, null): Behaviour<Option<{from:NS, to:NS}>>;
  public var currentProgress (default, null): Behaviour<PromiseD<Bool>>;

  var currentSource: BehaviourSource<NS>;
  var transitionSource: BehaviourSource<Option<{from:NS, to:NS}>>;
  var currentProgressSource: BehaviourSource<PromiseD<Bool>>;


  
  
  
  var phaseToInt : Phase -> Int;
  var eq:NS -> NS -> Bool;
  var handlers : IntMap<Array<Handler<NS, Dynamic, Dynamic>>>;
  var interceptors : Array<Interceptor<NS, Dynamic>>;
  var blockers : Array<NS->NS->Bool>;
  
  var allPhases:Array<Int>;
  
  //var blocker : NS->NS->Bool;
  
  @:noUsing public static function create<NS, Phase>(start:NS, eq:NS->NS->Bool, phaseToInt : Phase -> Int, allPhases:Array<Phase>) {
    return new Navigation(start, eq, phaseToInt, allPhases);
  }

  public function new(start:NS, eq:NS->NS->Bool, phaseToInt : Phase -> Int, allPhases:Array<Phase>) 
  {
    this.allPhases = allPhases.map(phaseToInt);
    
    
    handlers = new IntMap();
    for (p in this.allPhases) {
      handlers.set(p, []);
    }
    
    blockers = [];
    interceptors = [];
    this.phaseToInt = phaseToInt;
    
    this.eq = eq;
    
    transition = transitionSource = Behaviours.source(None);
    currentProgress = currentProgressSource = Behaviours.source(Promises.pure(true));
    current = currentSource = Behaviours.source(start);




  }
  
  function addGeneric <X>(phase:Phase, interested:NS->NS->Option<X>, run : X->PromiseD<Dynamic>):Bond 
  {
    var key = phaseToInt(phase);
    
    var a = handlers.get(key);
    if (a == null) {
      Scuts.error("unregistered phase: " + phase);
    } 
    
    return makeBond(a, { interested : interested, run : run } );
    
  }
  
  static function makeBond <T>(a:Array<T>, target:T ) 
  {
    a.push(target);
    var bond = new Bond(function () a.push(target), function () a.remove(target));
    return bond;
  }
  
  
  public function addSyncVoid <X,T>(phase: Phase, interested:NS->NS->Option<X>, run:Void->T):Bond {
    return addAsyncVoid(phase, interested, run.map(Promises.pure));
  }
  
  public function addAsyncVoid <X,T>(phase: Phase, interested:NS->NS->Option<X>, run:Void->PromiseD<T>):Bond {
    return addGeneric(phase, interested, run.promote());
  }
  
  public function addSync <X,T>(phase: Phase, interested:NS->NS->Option<X>, run:X->T):Bond {
    return addAsync(phase, interested, run.map(Promises.pure));
  }
  
  public function addAsync <X,T>(phase: Phase, interested:NS->NS->Option<X>, run:X->PromiseD<T>):Bond {
    return addGeneric(phase, interested, run);
  }
  
  public function addAsyncFromTo <X,T>(phaseFrom: Phase, phaseTo:Phase, interested:NS->NS->Option<X>, run:X->PromiseD<T>):Bond {
    Assert.isTrue(phaseToInt(phaseFrom) < phaseToInt(phaseTo));
    
    
    function newRun (x) 
    {
      var next = run(x);
      var bond2 = null;
      bond2 = addGeneric(phaseTo, function (_,_) return Some(true), function (_) { bond2.destroy(); return next; }); 
      return Promises.pure(Unit);
    }
    return addGeneric(phaseFrom, interested, newRun);
  }
  
  public function addInterceptorSyncVoid <X>(interested:NS->NS->Option<X>, run:Void->Bool):Bond {
    return addInterceptorAsyncVoid(interested, run.map(Promises.pure));
  }
  
  public function addBlocker <X>(blocker:NS->NS->Bool):Bond {
    return makeBond(blockers, blocker);
  }
  
  public function addInterceptorAsyncVoid <X>(interested:NS->NS->Option<X>, run:Void->PromiseD<Bool>):Bond {
    return makeBond(interceptors, { interested : interested, run : run.promote() } );
  }
  
  public function addInterceptorSync <X>(interested:NS->NS->Option<X>, run:X->Bool):Bond {
    return addInterceptorAsync(interested, run.map(Promises.pure));
  }
  
  public function addInterceptorAsync <X>(interested:NS->NS->Option<X>, run:X->PromiseD<Bool>):Bond {
    return makeBond(interceptors, { interested : interested, run : run } );
  }

  function setTarget (t:NS) 
  {
    var cur = current.get();
    currentSource.set(t);
    transitionSource.set(Some( { from: cur, to: t } ));
  }

  
  
  public function canGoto (state:NS):Bool {
    var from = current.get();
    return currentProgress.get().isComplete() && !eq(from, state);
  }
  
  public function goto (state:NS):PromiseD<Bool> 
  {
    return if (currentProgress.get().isComplete()) 
    {

      var from = current.get();
      
      if (eq(from, state)) 
      {
        Promises.pure(true);
      }
      else if (blockers.any(function (b) return b(from, state))) 
      {
        Promises.pure(false);
      } 
      else 
      {
        function handlersPromise (x:Bool) 
        {
          return if (x) 
          {
            var p = Promises.pure(true);

            for (key in allPhases) {
              var h = handlers.get(key);
              p = p.forceSwitchWith( function () return runHandlers(from, state, h));
            }
            
            p.onComplete(function (_) {trace("new Target" + state); setTarget(state);})
            .forceSwitchWith(function () return Promises.pure(true));
          } else {
            Promises.pure(false);
          }
        }
        var p = runInterceptors(from, state, interceptors).flatMap(handlersPromise);
        currentProgressSource.set(p);
        p;
      }
    } 
    else 
    {
      Promises.pure(false);
    }
  }
  
  function runInterceptors (from:NS, to:NS, interceptors:Array<Interceptor<NS, Dynamic>>):PromiseD<Bool>
  {
    var promises = interceptors
      .filterWithOption(function (x) return x.interested(from, to).map(function (v) return { handler:x, val:v } ))
      .map(function (x) return x.handler.run(x.val));
    return Promises.zipIterable(promises).map(function (x) return x.all(Scuts.id));
  }
  
  function runHandlers (from:NS, to:NS, handlers:Array<Handler<NS, Dynamic, Dynamic>>):PromiseD<Dynamic> {
    
    var promises = handlers
      .filterWithOption(function (x) return x.interested(from, to).map(function (v) return { handler:x, val:v }))
      .map(function (x) return x.handler.run(x.val));
    
    return Promises.zipIterable(promises);
  }
  
}