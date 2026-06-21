'use strict';

const { ApiError } = require('../utils/http');

/**
 * Validate a request part against a zod schema and replace it with parsed data.
 * @param {import('zod').ZodTypeAny} schema
 * @param {'body'|'query'|'params'} [part]
 */
function validate(schema, part = 'body') {
  return (req, _res, next) => {
    const result = schema.safeParse(req[part]);
    if (!result.success) {
      const details = result.error.issues.map((i) => ({
        path: i.path.join('.'),
        message: i.message,
      }));
      return next(ApiError.validation('Validation failed', details));
    }
    req[part] = result.data;
    next();
  };
}

module.exports = { validate };
