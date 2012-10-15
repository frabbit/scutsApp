package scuts.app.nav;


import scuts.core.extensions.Promises;
import scuts.core.extensions.Tup2s;
import scuts.core.types.Option;
import scuts.core.types.Promise;
import scuts.Unit;

using scuts.core.extensions.Functions;

using scuts.core.extensions.OptionPredicates;
using scuts.core.reactive.Behaviours;



enum Phase {
  First;
  Second;
  Third;
}

class Phases {
  
  public static function all () {
    return [First, Second, Third];
  }
  
  public static function toInt (p:Phase) {
    return switch (p) {
      case First: 1;
      case Second: 2;
      case Third : 3;
    }
  }
}

enum NaviTarget {
  Startup;
  Home(title:String);
  Contact(page:Int);
}

class NavigationTest 
{

  public function new () {}
  
  public function testHandlers() 
  {
    var nav = new Navigation(Startup, function (a,b) return a == b, Phases.toInt, Phases.all());
    var toHome = function (from, to) return switch (to) { case Home(title): Some(title); default: None; };
    
    var r = "false";
    
    nav.addSync(First, toHome, function (t) r = t);
    
    nav.goto(Home("hi"));
    
    utest.Assert.same("hi", r);
    
    
  }
  
  public function testAsyncHandlers() 
  {
    var nav = new Navigation(Startup, function (a,b) return a == b, Phases.toInt, Phases.all());
    var toHome = function (from, to) return switch (to) { case Home(title): Some(title); default: None; };
    
    var r = "false";
    
    var p1 = Promises.mk();
    var p2 = Promises.mk();
    
    nav.addAsync(First, toHome, function (t) return p1);
    nav.addAsync(First, toHome, function (t) return p2);
    
    nav.goto(Home("hi"));
    
    utest.Assert.same(Startup, nav.current.get());
    
    p1.complete(Unit);
    
    utest.Assert.same(Startup, nav.current.get());
    
    p2.complete(Unit);
    
    utest.Assert.same(Home("hi"), nav.current.get());
  }
  
  public function testBlocker() 
  {
    var nav = new Navigation(Startup, function (a,b) return a == b, Phases.toInt, Phases.all());
    var toHome = function (from, to) return switch (to) { case Home(title): Some(title); default: None; };
    
    
    var bond = nav.addBlocker(function (_,_) return true);
        
    nav.goto(Home("X"));
    
    utest.Assert.same(Startup, nav.current.get());
    
    
    bond.mute();
    
    nav.goto(Home("A"));
    
    utest.Assert.same(Home("A"), nav.current.get());
    
    bond.unmute();
    
    nav.goto(Home("B"));
    
    utest.Assert.same(Home("A"), nav.current.get());
  }
  
  public function testAsyncFromToHandler() 
  {
    var nav = new Navigation(Startup, function (a,b) return a == b, Phases.toInt, Phases.all());
    var toHome = function (from, to) return switch (to) { case Home(title): Some(title); default: None; };
    
    var r = "";
    
    var p1 = Promises.mk();

    nav.addAsyncFromTo(First, Third, toHome, function (t) return p1);
    nav.addSync(Second, toHome, function (t) r = "second");
    
    nav.goto(Home("hi"));
    
    utest.Assert.same("second", r);
    utest.Assert.same(Startup, nav.current.get());
    
    
    p1.complete(Unit);
    
    utest.Assert.same(Home("hi"), nav.current.get());
    
  }
  
  public function testHandlers2() 
  {
    var nav = new Navigation(Startup, function (a,b) return a == b, Phases.toInt, Phases.all());
    function toHome (from, to) return switch (to) { case Home(title): Some(title); default: None; };
    function fromHome(from, to) return switch (from) { case Home(title): Some(title); default: None; };
    
    var fromOtherToHome = fromHome.not().andSecond(toHome);
    var fromHomeToOther = fromHome.andFirst(toHome.not());
    var fromHomeToHome = fromHome.and(toHome);
    
    
    var homeToHome = "false";
    
    var x = nav.addSync(First, fromHomeToHome, function (titles) homeToHome = titles._1 + titles._2);
    
    var r = "false";
    
    
    var x = nav.addSync(First, fromOtherToHome, function (title) r = title);
    
    var r1 = "false";
    
    var x = nav.addSync(First, fromHomeToOther, function (title) r1 = title);
    
    
    nav.goto(Home("hi"));
    
    utest.Assert.same("hi", r);
    utest.Assert.same("false", r1);
    utest.Assert.same("false", homeToHome);
    
    nav.goto(Contact(1));
    
    utest.Assert.same("hi", r1);
    utest.Assert.same("false", homeToHome);
    
    
    nav.goto(Home("hi1"));
    
    utest.Assert.same("false", homeToHome);
    
    nav.goto(Home("hi2"));
    
    utest.Assert.same("hi1hi2", homeToHome);
    
    
    
    
  }
  
  
  
  public function testOrder() 
  {
    var nav = new Navigation(Startup, function (a,b) return a == b, Phases.toInt, Phases.all());
    function toHome (from, to) return switch (to) { case Home(title): Some(title); default: None; };
    
    
    
    var r = [];
    
    nav.addSyncVoid(Third, toHome, function () r.push(3));
    nav.addSyncVoid(Third, toHome, function () r.push(33));
    nav.addSyncVoid(First, toHome, function () r.push(1));
    nav.addSyncVoid(Second, toHome, function () r.push(2));
    nav.addSyncVoid(Second, toHome, function () r.push(22));
    
    nav.goto(Home("hi"));
    
    utest.Assert.same([1,2,22,3,33], r);
    
  }
  
  public function testInterceptors() 
  {
    var nav = new Navigation(Startup, function (a,b) return a == b, Phases.toInt, Phases.all());
    function toHome (from, to) return switch (to) { case Home(title): Some(title); default: None; };
    
    
    nav.addInterceptorSync(toHome, function (title) return title != "hi");
    
    
    nav.goto(Home("hi"));

    utest.Assert.same(Startup, nav.current.get());
    
    nav.goto(Home("hi2"));

    utest.Assert.same(Home("hi2"), nav.current.get());
    
  }
  
  public function testBond() 
  {
    var nav = new Navigation(Startup, function (a,b) return a == b, Phases.toInt, Phases.all());
    var toHome = function (from, to) return switch (to) { case Home(title): Some(title); default: None; };
    
    var r = "false";
    
    var bond = nav.addSync(First, toHome, function (t) r = t);
    bond.mute();
    
    nav.goto(Home("hi"));
    
    utest.Assert.same("false", r);
    
    bond.unmute();
    
    nav.goto(Home("hi2"));
    
    utest.Assert.same("hi2", r);
    
    bond.destroy();
    
    nav.goto(Home("hi3"));
    
    utest.Assert.same("hi2", r);
    
  }
  
}