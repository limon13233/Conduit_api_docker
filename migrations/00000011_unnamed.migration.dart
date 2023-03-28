import 'dart:async';
import 'package:conduit_core/conduit_core.dart';   

class Migration11 extends Migration { 
  @override
  Future upgrade() async {
   		database.deleteColumn("_Operation", "isDeleted");
  }
  
  @override
  Future downgrade() async {}
  
  @override
  Future seed() async {}
}
    