'use strict';

const bcrypt = require('bcryptjs');
const config = require('../config');

function hashPassword(plain) {
  return bcrypt.hash(plain, config.bcryptRounds);
}

function comparePassword(plain, hash) {
  return bcrypt.compare(plain, hash);
}

module.exports = { hashPassword, comparePassword };
