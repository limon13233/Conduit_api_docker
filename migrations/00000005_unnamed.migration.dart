import 'dart:async';
import 'package:conduit_core/conduit_core.dart';   

class Migration5 extends Migration { 
  @override
  Future upgrade() async {
   		database.alterColumn("_Operation", "operationName", (c) {c.isUnique = false;});
		database.alterColumn("_Operation", "operationDescription", (c) {c.isUnique = false;});
		database.alterColumn("_Operation", "operationType", (c) {c.isUnique = false;});
		database.alterColumn("_Operation", "operationDate", (c) {c.isUnique = false;});
		database.alterColumn("_Operation", "operationAmount", (c) {c.isUnique = false;});
  }
  
  @override
  Future downgrade() async {}
  
  @override
  Future seed() async {}
}
    