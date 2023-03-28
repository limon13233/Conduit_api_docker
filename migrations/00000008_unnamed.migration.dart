import 'dart:async';
import 'package:conduit_core/conduit_core.dart';   

class Migration8 extends Migration { 
  @override
  Future upgrade() async {
   		database.addColumn("_Operation", SchemaColumn("isDeleted", ManagedPropertyType.boolean, isPrimaryKey: false, autoincrement: false, isIndexed: true, isNullable: false, isUnique: false));
  }
  
  @override
  Future downgrade() async {}
  
  @override
  Future seed() async {}
}
    