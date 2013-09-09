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

class Navigation<NT, Phase> 
{
  
  
  
  public var current (default, null): BehaviourSource<NT>;
  public var transition (default, null): BehaviourSource<Option<{from:NT, to:NT}>>;
  public var currentProgress (default, null): BehaviourSource<PromiseD<Bool>>;
  
  
  
  var phaseToInt : Phase -> Int;
  var eq:NT -> NT -> Bool;
  var handlers : IntMap<Array<Handler<NT, Dynamic, Dynamic>>>;
  var interceptors : Array<Interceptor<NT, Dynamic>>;
  var blockers : Array<NT->NT->Bool>;
  
  var allPhases:Array<Int>;
  
  //var blocker : NT->NT->Bool;
  
  public function new(start:NT, eq:NT->NT->Bool, phaseToInt : Phase -> Int, allPhases:Array<Phase>) 
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
    
    transition = Behaviours.source(None);
    currentProgress = Behaviours.source(Promises.pure(true));
    current = Behaviours.source(start);
  }
  
  function addGeneric <X>(phase:Phase, interested:NT->NT->Option<X>, run : X->PromiseD<Dynamic>):Bond 
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
  
  
  public function addSyncVoid <X>(phase: Phase, interested:NT->NT->Option<X>, run:Void->Dynamic):Bond {
    return addAsyncVoid(phase, interested, run.map(Promises.pure));
  }
  
  public function addAsyncVoid <X>(phase: Phase, interested:NT->NT->Option<X>, run:Void->PromiseD<Dynamic>):Bond {
    return addGeneric(phase, interested, run.promote());
  }
  
  public function addSync <X>(phase: Phase, interested:NT->NT->Option<X>, run:X->Dynamic):Bond {
    return addAsync(phase, interested, run.map(Promises.pure));
  }
  
  public function addAsync <X>(phase: Phase, interested:NT->NT->Option<X>, run:X->PromiseD<Dynamic>):Bond {
    return addGeneric(phase, interested, run);
  }
  
  public function addAsyncFromTo <X>(phaseFrom: Phase, phaseTo:Phase, interested:NT->NT->Option<X>, run:X->PromiseD<Dynamic>):Bond {
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
  
  public function addInterceptorSyncVoid <X>(interested:NT->NT->Option<X>, run:Void->Bool):Bond {
    return addInterceptorAsyncVoid(interested, run.map(Promises.pure));
  }
  
  public function addBlocker <X>(blocker:NT->NT->Bool):Bond {
    return makeBond(blockers, blocker);
  }
  
  public function addInterceptorAsyncVoid <X>(interested:NT->NT->Option<X>, run:Void->PromiseD<Bool>):Bond {
    return makeBond(interceptors, { interested : interested, run : run.promote() } );
  }
  
  public function addInterceptorSync <X>(interested:NT->NT->Option<X>, run:X->Bool):Bond {
    return addInterceptorAsync(interested, run.map(Promises.pure));
  }
  
  public function addInterceptorAsync <X>(interested:NT->NT->Option<X>, run:X->PromiseD<Bool>):Bond {
    return makeBond(interceptors, { interested : interested, run : run } );
  }

  function setTarget (t:NT) 
  {
    var cur = current.get();
    current.set(t);
    transition.set(Some( { from: cur, to: t } ));
  }

  
  
  public function canGoto (target:NT):Bool {
    var from = current.get();
    return currentProgress.get().isComplete() && !eq(from, target);
  }
  
  public function goto (target:NT):PromiseD<Bool> 
  {
    return if (currentProgress.get().isComplete()) 
    {
      
      var from = current.get();
      
      if (blockers.any(function (b) return b(from, target))) {
        Promises.pure(false);
      } else {
      
        if (eq(from, target)) {
          Promises.pure(true);
        } else {
          
          function handlersPromise (x:Bool) 
          {
            return if (x) 
            {
              var p = Promises.pure(true);

              for (key in allPhases) {
                var h = handlers.get(key);
                p = p.then( function () return runHandlers(from, target, h));
              }
              
              p.onComplete(function (_) setTarget(target))
              .then(function () return Promises.pure(true));
            } else {
              Promises.pure(false);
            }
          }
          
          var p = runInterceptors(from, target, interceptors).flatMap(handlersPromise);
          currentProgress.set(p);
          p;
        }
      }
    } else {
      Promises.pure(false);
    }
  }
  
  function runInterceptors (from:NT, target:NT, interceptors:Array<Interceptor<NT, Dynamic>>):PromiseD<Bool>
  {
    var promises = interceptors
      .filterWithOption(function (x) return x.interested(from, target).map(function (v) return { handler:x, val:v } ))
      .map(function (x) return x.handler.run(x.val));
    return Promises.combineIterable(promises).map(function (x) return x.all(Scuts.id));
  }
  
  function runHandlers (from:NT, target:NT, handlers:Array<Handler<NT, Dynamic, Dynamic>>):PromiseD<Dynamic> {
    
    var promises = handlers
      .filterWithOption(function (x) return x.interested(from, target).map(function (v) return { handler:x, val:v }))
      .map(function (x) return x.handler.run(x.val));
    
    return Promises.combineIterable(promises);
  }
  
}