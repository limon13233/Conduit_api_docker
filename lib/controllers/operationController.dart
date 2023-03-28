import 'dart:async';
import 'dart:io';
import 'package:conduit/conduit.dart';
import 'package:conduit_api/models/model_response.dart';
import 'package:conduit_api/models/operation.dart';
import 'package:conduit_api/models/user.dart';
import 'package:conduit_api/utils/app_response.dart';
import 'package:conduit_api/utils/app_utils.dart';
import 'package:jaguar_jwt/jaguar_jwt.dart';

class AppOperationController extends ResourceController {
  AppOperationController(this.managedContext);

  final ManagedContext managedContext;

  @Operation.get()
  Future<Response> getAllOperations(
    @Bind.header(HttpHeaders.authorizationHeader) String header,
    @Bind.query("search") String name,
    @Bind.query("page") int page,
  ) async {
    if (page.isNaN || page < 1 || page == 1) page = 0;
    if (page > 1) page = (page - 1) * 10;

    if (name.isNotEmpty) {
      try {
        final uid = AppUtils.getIdFromHeader(header);

        final qUserOperation = Query<Operations>(managedContext)
          ..where((x) => x.operationName).contains(name, caseSensitive: false)
          ..where((x) => x.user!.id).equalTo(uid)
          ..offset = page
          ..fetchLimit = 10;

        final List<Operations> userOperations = await qUserOperation.fetch();

        if (userOperations.isEmpty)
          return AppResponse.ok(message: "Операции не найдены!");

        return Response.ok(userOperations);
      } on QueryException catch (e) {
        return AppResponse.serverError(e, message: e.message);
      }
    } else {
      try {
        final id = AppUtils.getIdFromHeader(header);

        final qUserOperations = Query<Operations>(managedContext)
          ..where((x) => x.user!.id).equalTo(id)
          ..offset = page
          ..fetchLimit = 10;

        final List<Operations> userOperations = await qUserOperations.fetch();

        if (userOperations.isEmpty)
          return AppResponse.ok(message: "Операции не найдены!");

        return Response.ok(userOperations);
      } on QueryException catch (e) {
        return Response.serverError(body: ModelResponse(message: e.message));
      }
    }
  }

  @Operation.get("id")
  Future<Response> getOperation(
      @Bind.header(HttpHeaders.authorizationHeader) String header,
      @Bind.path("id") int id) async {
    try {
      final uid = AppUtils.getIdFromHeader(header);

      final qUserOperation = Query<Operations>(managedContext)
        ..where((x) => x.operationID).equalTo(id)
        ..where((x) => x.user!.id).equalTo(uid);

      final Operations? userOperation = await qUserOperation.fetchOne();

      if (userOperation == null)
        return AppResponse.ok(message: "Операция не найдена!");

      final Operations? userOperation_ = await managedContext
          .fetchObjectWithID<Operations>(userOperation.operationID);
      userOperation_!.removePropertiesFromBackingMap(["user"]);

      return Response.ok(userOperation_);
    } on QueryException catch (e) {
      return AppResponse.serverError(e, message: e.message);
    }
  }

  @Operation.post()
  Future<Response> createOperation(
      @Bind.header(HttpHeaders.authorizationHeader) String header,
      @Bind.body() Operations operation) async {
    int newOperationId = -1;

    try {
      final uid = AppUtils.getIdFromHeader(header);
      final user = await managedContext.fetchObjectWithID<User>(uid);
      int newOperationId = -1;

      if (user == null)
        return AppResponse.ok(message: "Пользователь не найден!");

      await managedContext.transaction((transaction) async {
        final qCreateOperation = Query<Operations>(transaction)
          ..values.operationName = operation.operationName
          ..values.operationDescription = operation.operationDescription
          ..values.operationType = operation.operationType
          ..values.operationDate = operation.operationDate
          ..values.operationAmount = operation.operationAmount
          ..values.user = user;

        final createOperation = await qCreateOperation.insert();
        newOperationId = createOperation.operationID!;
      });

      final Operations? createdOperation =
          await managedContext.fetchObjectWithID<Operations>(newOperationId);
      createdOperation!.removePropertiesFromBackingMap(["user"]);

      return Response.ok(ModelResponse(
          data: createdOperation.backing.contents,
          message: "Операция успешно создана!"));
    } on QueryException catch (e) {
      return AppResponse.serverError(e, message: e.message);
    }
  }

  @Operation.delete("id")
  Future<Response> deleteOperation(
      @Bind.header(HttpHeaders.authorizationHeader) String header,
      @Bind.path("id") int id) async {
    try {
      final uid = AppUtils.getIdFromHeader(header);
      final operation = await managedContext.fetchObjectWithID<Operations>(id);

      if (operation == null)
        return Response.badRequest(body: "Операция не найдена!");

      if (operation.user?.id != uid)
        return AppResponse.ok(message: "У вас нет доступа к данной опреации!");

      final qOperationDelete = Query<Operations>(managedContext)
        ..where((x) => x.operationID).equalTo(id);

      qOperationDelete.delete();

      return AppResponse.ok(message: "Операция удалена!");
    } catch (e) {
      return AppResponse.serverError(e, message: "Произошла ошибка!");
    }
  }

  @Operation.put("id")
  Future<Response> updateOperation(
      @Bind.header(HttpHeaders.authorizationHeader) String header,
      @Bind.body() Operations operation,
      @Bind.path("id") int id) async {
    try {
      final uid = AppUtils.getIdFromHeader(header);
      final user = await managedContext.fetchObjectWithID<User>(uid);

      final currentOperation =
          await managedContext.fetchObjectWithID<Operations>(id);

      if (user == null)
        return AppResponse.ok(message: "Пользователь не найден!");

      if (user.id != currentOperation?.user?.id)
        return AppResponse.ok(message: "У вас нет доступа к данной опреации!");

      final qUpdateOperation = Query<Operations>(managedContext)
        ..where((x) => x.operationID).equalTo(id)
        ..values.operationName = operation.operationName
        ..values.operationDescription = operation.operationDescription
        ..values.operationType = operation.operationType
        ..values.operationDate = operation.operationDate
        ..values.operationAmount = operation.operationAmount;

      qUpdateOperation.update();

      return AppResponse.ok(message: "Операция изменена!");
    } on QueryException catch (e) {
      return AppResponse.serverError(e, message: e.message);
    }
  }
}
