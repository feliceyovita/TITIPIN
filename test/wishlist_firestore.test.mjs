// Jalankan dengan node --test ketika Auth dan Firestore Emulator aktif.
import assert from 'node:assert/strict';
import { test } from 'node:test';

const project = 'titipin-compsci';
const auth = 'http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1';
const db = 'http://127.0.0.1:8080/v1/projects/' + project + '/databases/(default)/documents';

async function request(method, url, token, body) {
  return fetch(url, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: 'Bearer ' + token } : {}),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
}

async function account(label, run) {
  const credentials = {
    email: 'wishlist-' + label + '-' + run + '@students.usu.ac.id',
    password: 'Local-wishlist-' + run, returnSecureToken: true,
  };
  const create = await request('POST', auth + '/accounts:signUp?key=demo', null, credentials);
  assert.equal(create.status, 200);
  const { localId } = await create.json();
  const verify = await request('POST', auth + '/projects/' + project + '/accounts:update',
      'owner', { localId, emailVerified: true });
  assert.equal(verify.status, 200, await verify.text());
  const signIn = await request('POST', auth + '/accounts:signInWithPassword?key=demo', null, credentials);
  assert.equal(signIn.status, 200);
  return signIn.json();
}

test('dua akun terpisah, simpan idempoten, listing hilang, hapus favorit', async () => {
  const run = Date.now();
  const [a, b] = await Promise.all([account('a', run), account('b', run)]);
  const item = 'buku-' + run;
  const path = (u) => db + '/users/' + u.localId + '/wishlist/' + item;
  const listing = db + '/barang/' + item;
  const fields = {
    namaBarang: { stringValue: 'Buku Algoritma' }, harga: { integerValue: '75000' },
    kategori: { stringValue: 'Buku' }, kategoriId: { stringValue: 'buku' },
    kondisi: { stringValue: 'Bekas - Tanpa minus' }, fotoUrl: { stringValue: '' },
  };
  const fixture = { ...fields, statusBarang: { stringValue: 'tersedia' },
    deskripsi: { stringValue: 'Buku algoritma untuk kuliah.' },
    lokasi: { stringValue: 'USU' }, userId: { stringValue: a.localId } };
  const seed = await request('PATCH', listing, 'owner', { fields: fixture });
  assert.equal(seed.status, 200, await seed.text());
  for (const user of [a, a, b]) {
    const saved = await request('PATCH', path(user), user.idToken, { fields });
    assert.equal(saved.status, 200, await saved.text());
  }
  const list = await request('GET', db + '/users/' + a.localId + '/wishlist', a.idToken);
  assert.equal((await list.json()).documents.length, 1);
  assert.equal((await request('GET', path(a), b.idToken)).status, 403);
  assert.equal((await request('DELETE', path(a), b.idToken)).status, 403);
  assert.equal((await request('PATCH', listing, 'owner', { fields: {
    ...fixture, statusBarang: { stringValue: 'terjual' },
  } })).status, 200);
  assert.equal((await request('GET', path(a), a.idToken)).status, 200);
  assert.equal((await request('DELETE', listing, 'owner')).status, 200);
  assert.equal((await request('DELETE', path(a), a.idToken)).status, 200);
  assert.equal((await request('GET', path(a), a.idToken)).status, 404);
  const remaining = await request('GET', path(b), b.idToken);
  assert.equal(remaining.status, 200);
  assert.deepEqual((await remaining.json()).fields, fields);
  console.log('Dokumen bukti emulator: users/' + b.localId + '/wishlist/' + item);
});
