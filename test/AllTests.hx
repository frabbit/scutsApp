package;




import scuts.app.nav.HistoryTest;
import scuts.app.nav.NavigationTest;
import utest.Runner;
import utest.ui.Report;


class AllTests 
{
  

  public static function main() 
  {
    
     
    var runner = new Runner();
    
    runner.addCase(new NavigationTest());
    runner.addCase(new HistoryTest());

    
    Report.create(runner);
    
    runner.run();
  }
}