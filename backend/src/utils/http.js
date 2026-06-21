'use strict';

/** Standard application error with HTTP status + machine code. */
class ApiError extends Error {
  constructor(status, code, message, details) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
    this.code = code;
    this.details = details;
  }

  static badRequest(message = 'Bad request', details) {
    return new ApiError(400, 'BAD_REQUEST', message, details);
  }
  static unauthorized(message = 'Unauthorized') {
    return new ApiError(401, 'UNAUTHORIZED', message);
  }
  static forbidden(message = 'Forbidden') {
    return new ApiError(403, 'FORBIDDEN', message);
  }
  static notFound(message = 'Not found') {
    return new ApiError(404, 'NOT_FOUND', message);
  }
  static conflict(message = 'Conflict') {
    return new ApiError(409, 'CONFLICT', message);
  }
  static validation(message = 'Validation failed', details) {
    return new ApiError(422, 'VALIDATION_ERROR', message, details);
  }
}

/** Wrap an async route handler so thrown errors reach the error middleware. */
function asyncHandler(fn) {
  return (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);
}

/** Success response helper. */
function ok(res, data, status = 200) {
  return res.status(status).json({ data });
}

/** Paginated success response helper. */
function paginated(res, data, meta) {
  return res.status(200).json({ data, meta });
}

module.exports = { ApiError, asyncHandler, ok, paginated };
