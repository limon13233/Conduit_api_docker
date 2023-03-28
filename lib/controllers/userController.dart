import 'dart:io';
import 'package:conduit/conduit.dart';
import 'package:conduit_api/models/model_response.dart';
import 'package:conduit_api/models/user.dart';
import 'package:conduit_api/utils/app_response.dart';
import 'package:conduit_api/utils/app_utils.dart';
import 'package:jaguar_jwt/jaguar_jwt.dart';

class AppUserController extends ResourceController {
  AppUserController(this.managedContext);

  final ManagedContext managedContext;
  @Operation.get()
  Future<Response> getUser(@Bind.header(HttpHeaders.authorizationHeader) String header) async{
    try{
      final id = AppUtils.getIdFromHeader(header);
      final user = await managedContext.fetchObjectWithID<User>(id);

      user!.removePropertiesFromBackingMap(['refreshToken', 'accessToken']);

      return AppResponse.ok(message: "Профиль пользователя: ", body: user.backing.contents);
    } on QueryException catch(e) {
      return AppResponse.serverError(e, message: "Произошла ошибка!");
    }
  }

  @Operation.post()
  Future<Response> updateUser(
    @Bind.header(HttpHeaders.authorizationHeader) String header,
    @Bind.body() User user) async {
      try {
        final id = AppUtils.getIdFromHeader(header);
        final user_ = await managedContext.fetchObjectWithID<User>(id);

        final qUserUpdate = Query<User>(managedContext)
          ..where((x) => x.id).equalTo(id)
          ..values.userName = user.userName ?? user_!.userName
          ..values.email = user.email ?? user_!.email;

        await qUserUpdate.updateOne();

        final findUser = await managedContext.fetchObjectWithID<User>(id);

        findUser!.removePropertiesFromBackingMap(['refreshToken', 'accessToken']);

        return AppResponse.ok(
          message: "Данные изменены!",
          body: findUser.backing.contents
        );

      } catch(e) {
        return AppResponse.serverError(e, message: "Произошла ошибка!");
      }
  }

  @Operation.put()
  Future<Response> updateUserPassword(
    @Bind.header(HttpHeaders.authorizationHeader) String header,
    @Bind.query('oldPassword') String oldPassword,
    @Bind.query('newPassword') String newPassword
  ) async {
    try{
      final id = AppUtils.getIdFromHeader(header);

      final qFindUser = Query<User>(managedContext)
        ..where((x) => x.id).equalTo(id)
        ..returningProperties((x) => [
          x.salt,
          x.hashPassword
        ]); 

      final user_ = await qFindUser.fetchOne();

      final oldHashPassword = generatePasswordHash(oldPassword, user_!.salt ?? "");

      if(oldHashPassword != user_.hashPassword){
        return Response.badRequest(body: ModelResponse(message: "Неверный пароль!"));
      }

      final newHashPassword = generatePasswordHash(newPassword, user_.hashPassword ?? "");

      final qUpdateUser = Query<User>(managedContext)
        ..where((x) => x.id).equalTo(id)
        ..values.hashPassword = newHashPassword;

      await qUpdateUser.updateOne();

      return AppResponse.ok(message: "Пароль изменён!");

    } catch(e) {
      return AppResponse.serverError(e, message: "Произошла ошибка!");
    }
  }

  @Operation.post('refresh')
  Future<Response> refreshToken(@Bind.path('refresh') String refreshToken) async {
    try {
      final id = AppUtils.getIdFromToken(refreshToken);

      final user = await managedContext.fetchObjectWithID<User>(id);

      if(user!.refreshToken != refreshToken) {
        return Response.unauthorized(body: 'Token не валидный!');
      }

      _updateTokens(id, managedContext);

      return Response.ok(
        ModelResponse(
          data: user.backing.contents,
          message: 'Токен успешно обновлён!')
      );
    } on QueryException catch(e) {
      return Response.serverError(body: ModelResponse(message: e.message));
    }
  }

  void _updateTokens(int id, ManagedContext transaction) async {
    final Map<String, String> tokens = _getTokens(id);

    final qUpdateTokens = Query<User>(transaction)
      ..where((element) => element.id).equalTo(id)
      ..values.accessToken = tokens['access']
      ..values.refreshToken = tokens['refresh'];

    await qUpdateTokens.updateOne();
  }

  Map<String, String> _getTokens(int id) {
    final key = Platform.environment['SECRET_KEY'] ?? 'SECRET_KEY';
    final accessClaimSet = JwtClaim(
      maxAge: const Duration(hours: 1),
      otherClaims: {'id': id}
    );

    final refreshClaimSet = JwtClaim(
      otherClaims: {'id': id}
    );

    final tokens = <String, String>{};
    tokens['access'] = issueJwtHS256(accessClaimSet, key);
    tokens['refresh'] = issueJwtHS256(refreshClaimSet, key);

    return tokens;
  }

}