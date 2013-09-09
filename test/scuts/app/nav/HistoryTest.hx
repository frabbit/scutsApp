package scuts.app.nav;


import scuts.core.Promises;
import scuts.core.Tup2s;
import scuts.core.Option;
import scuts.core.Promise;
import scuts.Unit;

using scuts.core.Functions;

using scuts.core.OptionPredicates;
using scuts.reactive.Behaviours;


import scuts.app.nav.NavigationTest;

class HistoryTest 
{

  public function new () {}
  
  public function testBack() 
  {
    var nav = new Navigation(Startup, function (a,b) return a == b, Phases.toInt, Phases.all());
    var history = new History(nav);
    
    
    nav.goto(Home("hi"));
    
    history.back();
    
    utest.Assert.same(Startup, nav.current.get());
    
    
  }
  
  public function testBackTwice() 
  {
    var nav = new Navigation(Startup, function (a,b) return a == b, Phases.toInt, Phases.all());
    var history = new History(nav);
    
    
    nav.goto(Home("hi"));
    nav.goto(Contact(1));
    
    
    history.back();
    history.back();
    
    utest.Assert.same(Startup, nav.current.get());
    
    
  }
  
  public function testBackAndForward() 
  {
    var nav = new Navigation(Startup, function (a,b) return a == b, Phases.toInt, Phases.all());
    var history = new History(nav);
    
    
    nav.goto(Home("hi"));
    
    
    
    history.back();
    
    utest.Assert.same(Startup, nav.current.get());
    
    history.forward();
    
    utest.Assert.same(Home("hi"), nav.current.get());
    
    
  }
  
  public function testBackAndForwardOnEmptyHistory() 
  {
    var nav = new Navigation(Startup, function (a,b) return a == b, Phases.toInt, Phases.all());
    var history = new History(nav);

    history.back();
    
    utest.Assert.same(Startup, nav.current.get());
    
    history.forward();
    
    utest.Assert.same(Startup, nav.current.get());
    
    
  }
  
  public function testBackUntil() 
  {
    var nav = new Navigation(Startup, function (a,b) return a == b, Phases.toInt, Phases.all());
    var history = new History(nav);

    
    nav.goto(Home("A"));
    nav.goto(Home("B"));
    nav.goto(Contact(1));
    
    history.backUntil(function (x) return switch x { case Home(a): a == "A"; default: false; });
    
    utest.Assert.same(Home("A"), nav.current.get());
  }
  
  public function testHistoryOverwrite() 
  {
    var nav = new Navigation(Startup, function (a,b) return a == b, Phases.toInt, Phases.all());
    var history = new History(nav);

    
    nav.goto(Home("A"));
    nav.goto(Home("B"));
    nav.goto(Contact(1));
    
    history.back();
    
    nav.goto(Contact(2));
    
    
    utest.Assert.same([Startup, Home("A"), Home("B"), Contact(2)], history.entries);
  }
  
  public function testHistoryOverwriteMultiple() 
  {
    var nav = new Navigation(Startup, function (a,b) return a == b, Phases.toInt, Phases.all());
    var history = new History(nav);

    
    nav.goto(Home("A"));
    nav.goto(Home("B"));
    nav.goto(Contact(1));
    
    history.back();
    history.back();
    history.back();
    
    nav.goto(Contact(2));
    
    
    utest.Assert.same([Startup, Contact(2)], history.entries);
  }
  
}