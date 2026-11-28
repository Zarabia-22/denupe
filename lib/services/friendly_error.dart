import 'denupe_api.dart';

String friendlyError(Object error) => error is DenupeApiException
    ? error.message
    : 'No se pudo completar la operación. Inténtalo de nuevo.';
