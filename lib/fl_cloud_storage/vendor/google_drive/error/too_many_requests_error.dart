/// If the Google Drive API was already used a few times, it may return with an error.
///
/// The error thrown is DetailedApiRequestError(
///   status: 401,
///   message:
///     Request had invalid authentication credentials.
///     Expected Auth 2 access token, login cookie or other valid authentication credential.
/// )
class TooManyRequestsError extends Error {
  TooManyRequestsError();
}
