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

async function account(label, run, domain = 'students.usu.ac.id') {
  const credentials = {
    email: 'wishlist-' + label + '-' + run + '@' + domain,
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

test('nomor registrasi privat hingga dipindahkan ke profil penjual terverifikasi', async () => {
  const run = Date.now();
  const credentials = {
    email: 'phone-' + run + '@students.usu.ac.id',
    password: 'Local-phone-' + run,
    returnSecureToken: true,
  };
  const response = await request('POST', auth + '/accounts:signUp?key=demo', null, credentials);
  assert.equal(response.status, 200);
  const user = await response.json();
  const other = await account('phone-reader', run);
  const pending = '/users/' + user.localId + '/private/registration';
  const profile = '/users/' + user.localId + '/public/profile';
  const fields = { nomorTelepon: { stringValue: '6281234567890' } };
  assert.equal((await request('PATCH', db + pending, other.idToken, { fields })).status, 403);
  assert.equal((await request('PATCH', db + pending, user.idToken, {
    fields: { nomorTelepon: { stringValue: 'invalid' } },
  })).status, 403);
  assert.equal((await request('PATCH', db + pending, user.idToken, { fields })).status, 200);
  assert.equal((await request('GET', db + pending, other.idToken)).status, 403);
  assert.equal((await request('GET', db + pending, user.idToken)).status, 403);

  const profileFields = {
    ...fields,
    nama: { stringValue: 'Penjual uji' },
    isSellerVerified: { booleanValue: true },
  };
  assert.equal((await request('PATCH', db + profile, user.idToken, { fields: profileFields })).status, 403);
  const verified = await request('POST', auth + '/projects/' + project + '/accounts:update',
      'owner', { localId: user.localId, emailVerified: true });
  assert.equal(verified.status, 200);
  const login = await request('POST', auth + '/accounts:signInWithPassword?key=demo', null, credentials);
  const { idToken } = await login.json();
  assert.equal((await request('PATCH', db + profile, idToken, { fields: profileFields })).status, 403);
  const name = (path) => 'projects/' + project + '/databases/(default)/documents' + path;
  const committed = await request('POST', db + ':commit', idToken, {
    writes: [{ update: { name: name(profile), fields: profileFields } }, { delete: name(pending) }],
  });
  assert.equal(committed.status, 200, await committed.text());
  assert.equal((await request('GET', db + pending, idToken)).status, 404);
  const publicProfile = await request('GET', db + profile, other.idToken);
  assert.equal(publicProfile.status, 200);
  assert.deepEqual((await publicProfile.json()).fields.nomorTelepon, fields.nomorTelepon);
});

test('pemilik profil lama dapat mengubah nomor, pengguna lain dan nomor rusak ditolak', async () => {
  const run = Date.now();
  const [a, b] = await Promise.all([account('legacy', run), account('reader', run)]);
  const profile = db + '/users/' + a.localId + '/public/profile';
  const fields = { nama: { stringValue: 'Penjual' }, isSellerVerified: { booleanValue: true } };
  assert.equal((await request('PATCH', profile, 'owner', { fields })).status, 200);
  fields.nomorTelepon = { stringValue: '6281234567890' };
  assert.equal((await request('PATCH', profile, a.idToken, { fields })).status, 200);
  fields.nomorTelepon = { stringValue: '6289876543210' };
  assert.equal((await request('PATCH', profile, b.idToken, { fields })).status, 403);
  assert.equal((await request('PATCH', profile, a.idToken, { fields })).status, 200);
  fields.nomorTelepon = { stringValue: 'abc' };
  assert.equal((await request('PATCH', profile, a.idToken, { fields })).status, 403);
});

test('aturan barang memeriksa domain, kepemilikan, foto, dan penghapusan akun', async () => {
  const run = Date.now();
  const [a,b,external] = await Promise.all([
    account('owner', run), account('other', run), account('external', run, 'example.org'),
  ]);
  const item = 'barang-' + run;
  const list = db + '/barang/' + item;
  const name = 'projects/' + project + '/databases/(default)/documents/barang/' + item;
  const str = stringValue => ({ stringValue });
  const photoId = 'asset000' + String(run).slice(-12);
  const photo = {
    publicId: str('titipin/' + photoId), url: str('https://example.org/foto.jpg'),
  };
  const fields = {
    namaBarang: str('Buku'), harga: { integerValue: '30000' }, kategoriId: str('buku'),
    kondisi: str('Bekas'), lokasi: str('USU'), deskripsi: str('Buku catatan kuliah.'),
    statusBarang: str('tersedia'), barangId: str(item), userId: str(a.localId),
    fotoBarang: { arrayValue: { values: [{ mapValue: { fields: photo } }] } },
  };
  const create = token => request('POST', db + ':commit', token, {writes: [{
    update: {name, fields}, updateTransforms: ['createdAt','updatedAt'].map(fieldPath =>
      ({fieldPath, setToServerValue: 'REQUEST_TIME'})),
  }]});
  await request('PATCH', db + '/kategori/buku', 'owner', {fields: {namaKategori: str('Buku')}});
  const badUrlFields = {
    ...fields,
    fotoBarang: { arrayValue: { values: [{ mapValue: { fields: {
      publicId: str('titipin/bad'), url: str('http://example.org/foto.jpg'),
    } } }] } },
  };
  assert.equal((await request('POST', db + ':commit', a.idToken, {writes: [{
    update: {name, fields: badUrlFields}, updateTransforms: ['createdAt','updatedAt'].map(fieldPath =>
      ({fieldPath, setToServerValue: 'REQUEST_TIME'})),
  }]})).status, 403);
  // Five photos is the maximum supported by the upload form.
  for (let i = 1; i < 5; i++) {
    const id = String(i) + photoId.slice(1);
    const extra = { publicId: str('titipin/' + id), url: str('https://example.org/' + id) };
    fields.fotoBarang.arrayValue.values.push({mapValue: {fields: extra}});
  }
  const ok = await create(a.idToken);
  assert.equal(ok.status, 200, await ok.text());
  assert.equal((await request('GET', list, external.idToken)).status, 403);
  assert.equal((await request('GET', db + '/users/' + a.localId + '/public/profile', external.idToken)).status, 403);
  const update = (token, key, value) => request('POST', db + ':commit', token, {writes: [{
    update: {name, fields: {[key]: value}}, updateMask: {fieldPaths: [key]},
    updateTransforms: [{fieldPath: 'updatedAt', setToServerValue: 'REQUEST_TIME'}],
  }]});
  assert.equal((await update(a.idToken, 'statusBarang', str('terjual'))).status, 200);
  assert.equal((await update(a.idToken, 'userId', str(b.localId))).status, 403);
  assert.equal((await update(b.idToken, 'harga', { integerValue: '10' })).status, 403);
  assert.equal((await request('DELETE', list, b.idToken)).status, 403);
  await request('PATCH', db + '/deletedAccounts/' + a.localId, 'owner', {fields:{deleted: {booleanValue:true}}});
  assert.equal((await update(a.idToken, 'statusBarang', str('tersedia'))).status, 403);
  assert.equal((await request('DELETE', list, a.idToken)).status, 403);
});
