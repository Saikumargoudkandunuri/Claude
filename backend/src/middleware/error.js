'use strict';

const { ApiError } = require('../utils/http');

// eslint-disable-next-line no-unused-vars
function errorHandler(err, req, res, _next) {
  // Known application errors
  if (err instanceof ApiError) {
    return res.status(err.status).json({
      error: { code: err.code, message: err.message, details: err.details },
    });
  }

  // PostgreSQL unique violation -> 409
  if (err && err.code === '23505') {
    return res.status(409).json({
      error: { code: 'CONFLICT', message: 'Resource already exists' },
    });
  }
  // Foreign key violation -> 400
  if (err && err.code === '23503') {
    return res.status(400).json({
      error: { code: 'BAD_REFERENCE', message: 'Referenced resource does not exist' },
    });
  }
  // Multer file-size error
  if (err && err.code === 'LIMIT_FILE_SIZE') {
    return res.status(413).json({
      error: { code: 'FILE_TOO_LARGE', message: 'Uploaded file exceeds size limit' },
    });
  }

  // Fallback
  if (req.log) req.log.error({ err }, 'Unhandled error');
  else console.error('Unhandled error', err); // eslint-disable-line no-console

  return res.status(500).json({
    error: { code: 'INTERNAL_ERROR', message: 'Something went wrong' },
  });
}

module.exports = { errorHandler };
