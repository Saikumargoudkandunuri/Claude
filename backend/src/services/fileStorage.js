'use strict';

/**
 * File storage abstraction. Default driver is local disk (Hostinger compatible).
 * Swap STORAGE_DRIVER=s3 and implement the s3 driver to move to object storage
 * without touching callers.
 */
const fs = require('fs');
const fsp = require('fs/promises');
const path = require('path');
const crypto = require('crypto');
const config = require('../config');

function sanitize(name) {
  return String(name || 'file')
    .replace(/[^\w.\-]+/g, '_')
    .slice(0, 120);
}

const localDriver = {
  /**
   * Persist a buffer to disk.
   * @returns {Promise<{storageKey:string,sizeBytes:number}>}
   */
  async save(buffer, { projectId, category, originalName }) {
    const safeName = sanitize(originalName);
    const unique = `${Date.now()}-${crypto.randomBytes(6).toString('hex')}-${safeName}`;
    const relDir = path.join(projectId, category);
    const absDir = path.join(config.storage.dir, relDir);
    await fsp.mkdir(absDir, { recursive: true });
    const absPath = path.join(absDir, unique);
    await fsp.writeFile(absPath, buffer);
    return {
      storageKey: path.join(relDir, unique).split(path.sep).join('/'),
      sizeBytes: buffer.length,
    };
  },

  async remove(storageKey) {
    if (!storageKey) return;
    const abs = path.join(config.storage.dir, storageKey);
    try {
      await fsp.unlink(abs);
    } catch (err) {
      if (err.code !== 'ENOENT') throw err;
    }
  },

  /** Returns an absolute path for streaming/sendFile. */
  absolutePath(storageKey) {
    return path.join(config.storage.dir, storageKey);
  },

  exists(storageKey) {
    return fs.existsSync(this.absolutePath(storageKey));
  },

  createReadStream(storageKey, options) {
    return fs.createReadStream(this.absolutePath(storageKey), options);
  },

  async stat(storageKey) {
    return fsp.stat(this.absolutePath(storageKey));
  },
};

// Placeholder for future S3 driver; throws clearly if selected before impl.
const s3Driver = new Proxy(
  {},
  {
    get() {
      throw new Error('S3 storage driver not yet implemented. Use STORAGE_DRIVER=local.');
    },
  }
);

const driver = config.storage.driver === 's3' ? s3Driver : localDriver;

module.exports = driver;
