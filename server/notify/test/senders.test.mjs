import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createSenders } from '../src/senders.mjs';

test('senderFor: web có, fcm chưa có thì null', () => {
  const web = { send() {} };
  const s = createSenders({ web });
  assert.equal(s.senderFor('web'), web);
  assert.equal(s.senderFor('fcm'), null);
  assert.equal(s.senderFor('khac'), null);
  const fcm = { send() {} };
  assert.equal(createSenders({ web, fcm }).senderFor('fcm'), fcm);
});
