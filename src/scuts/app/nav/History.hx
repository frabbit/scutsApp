package scuts.app.nav;
import scuts.core.debug.Assert;
import scuts.reactive.Behaviour;
import scuts.core.Promise;
using scuts.reactive.Behaviours;
using scuts.reactive.Streams;
using scuts.core.Promises;
using scuts.core.Arrays;


class History<NT, Phase>
{

  public var entries : Array<NT>;
  var index : Int;
  var nav:Navigation<NT, Phase>;
  
  var enablePush : Bool = true;
  
  public function new(nav:Navigation<NT, Phase>) 
  {
    index = 0;
    this.nav = nav;
    entries = [nav.current.get()];
    nav.current.changes().each(function (v) 
    {
      if (enablePush) 
      {
        index += 1;
        entries = entries.take(index);
        
        entries.push(v);
      }
      
    });
  }
  
  public function goto(target:NT, ?useHistory:Bool = true):Promise<Bool> 
  {
    return if (useHistory) 
    {
      nav.goto(target);
    } 
    else 
    {
      enablePush = false;
      var p = nav.goto(target);
      p.onComplete(function (_) enablePush = true);
      p.onCancelled(function () enablePush = true);
      p;
    }
  }
  
  public function back():Promise<Bool> 
  {
    return to(index - 1);
  }
  
  public function backUntil(f:NT->Bool):Promise<Bool> 
  {
    var i = index - 1;
    while (i > -1 && !f(entries[i])) 
    {
      i--;
    }
    return to(i);
  }
  
  public function forward():Promise<Bool> 
  {
    return to(index + 1);
  }

  function validIndex (i:Int):Bool {
    return i >= 0 && i < entries.length;
  }
  
  public function to(newIndex:Int):Promise<Bool> 
  {
    return if (validIndex(newIndex)) 
    {
      enablePush = false;
      
      var target = entries[newIndex];

      var r = nav.goto(target);
      r.onComplete(function (s) 
      {
        if (s) index = newIndex;
        
        enablePush = true;
      });
      r.onCancelled(function () 
      {
        enablePush = true;
      });
      r;
    } else {
      Promises.pure(false);
    }
  }
  
  
  
}