require('dotenv').config();
const express = require('express');
const cors = require('cors');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const sql = require('mssql');

const app = express();

// Konfigurasi CORS yang lebih aman dan kompatibel
app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  preflightContinue: false,
  optionsSuccessStatus: 204
}));

app.use(express.json({ limit: '50mb' }));

const BASE_URL = process.env.BASE_URL || 'http://192.168.0.135:3000';

const requiredEnv = ['DB_USER', 'DB_PASSWORD', 'DB_SERVER', 'DB_NAME', 'JWT_SECRET'];
const missingEnv = requiredEnv.filter((key) => !process.env[key]);
if (missingEnv.length > 0) {
  console.error(`Missing required environment variables: ${missingEnv.join(', ')}`);
  process.exit(1);
}

const dbConfig = {
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  server: process.env.DB_SERVER,
  database: process.env.DB_NAME,
  port: process.env.DB_PORT ? parseInt(process.env.DB_PORT, 10) : undefined,
  options: { encrypt: false, trustServerCertificate: true }
};

const poolPromise = new sql.ConnectionPool(dbConfig).connect();

const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];
  if (!token) return res.status(401).json({ message: 'Token tidak ditemukan' });

  jwt.verify(token, process.env.JWT_SECRET, (err, user) => {
    if (err) return res.status(403).json({ message: 'Token tidak valid' });
    req.user = user;
    next();
  });
};

async function ensureDatabaseTables() {
  const pool = await poolPromise;
  await pool.request().query(`
    IF OBJECT_ID(N'dbo.users', N'U') IS NULL
    BEGIN
      CREATE TABLE dbo.users (
        id INT IDENTITY(1,1) PRIMARY KEY,
        username NVARCHAR(100) UNIQUE NOT NULL,
        password_hash NVARCHAR(255) NOT NULL
      );
    END
    IF OBJECT_ID(N'dbo.hotwheels_collection', N'U') IS NULL
    BEGIN
      CREATE TABLE dbo.hotwheels_collection (
        id NVARCHAR(50) PRIMARY KEY,
        user_id INT NOT NULL,
        tgl_pembelian NVARCHAR(50),
        lokasi_beli NVARCHAR(255),
        harga_beli DECIMAL(18,2) NULL,
        nama_kendaraan NVARCHAR(255),
        penomoran NVARCHAR(255),
        kategori_kendaraan NVARCHAR(255),
        penomoran_kategori NVARCHAR(255),
        kode_hotwheel NVARCHAR(255),
        kendaraan NVARCHAR(50),
        tahun_kendaraan INT NULL,
        trackstar BIT DEFAULT 0,
        special_kategori NVARCHAR(255),
        netflix BIT DEFAULT 0,
        hotwheel_showdown BIT DEFAULT 0,
        warna_1 NVARCHAR(100) NOT NULL,
        warna_2 NVARCHAR(100),
        foto NVARCHAR(MAX) NULL
      );
    END
  `);
}

app.post('/register', async (req, res) => {
  try {
    const { username, password } = req.body;
    if (!username || !password) {
      return res.status(400).json({ message: 'Username dan password wajib diisi' });
    }

    const pool = await poolPromise;
    const existing = await pool.request()
      .input('username', sql.NVarChar(100), username)
      .query('SELECT TOP 1 id FROM dbo.users WHERE username = @username');

    if (existing.recordset.length > 0) {
      return res.status(409).json({ message: 'Username sudah digunakan' });
    }

    const hashedPassword = await bcrypt.hash(password, 10);
    await pool.request()
      .input('username', sql.NVarChar(100), username)
      .input('password_hash', sql.NVarChar(255), hashedPassword)
      .query('INSERT INTO dbo.users (username, password_hash) VALUES (@username, @password_hash)');

    res.status(201).json({ message: 'User berhasil dibuat' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message });
  }
});

app.post('/login', async (req, res) => {
  try {
    const { username, password } = req.body;
    if (!username || !password) {
      return res.status(400).json({ message: 'Username dan password wajib diisi' });
    }

    const pool = await poolPromise;
    const result = await pool.request()
      .input('username', sql.NVarChar(100), username)
      .query('SELECT TOP 1 * FROM dbo.users WHERE username = @username');

    const user = result.recordset[0];
    if (!user || !(await bcrypt.compare(password, user.password_hash))) {
      return res.status(401).json({ message: 'Username atau password salah' });
    }

    const token = jwt.sign({ id: user.id, username: user.username }, process.env.JWT_SECRET, { expiresIn: '24h' });
    res.json({ token, userId: user.id, message: 'Login berhasil' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/sync', authenticateToken, async (req, res) => {
  try {
    const data = Array.isArray(req.body) ? req.body : [];
    const pool = await poolPromise;

    for (let item of data) {
      const trackstar = item.trackstar ? 1 : 0;
      const netflix = item.netflix ? 1 : 0;
      const hotwheelShowdown = item.hotwheel_showdown ? 1 : 0;
      const hargaBeli = item.harga_beli !== undefined && item.harga_beli !== null ? parseFloat(item.harga_beli) : null;
      const tahunKendaraan = item.tahun_kendaraan !== undefined && item.tahun_kendaraan !== null ? parseInt(item.tahun_kendaraan, 10) : null;

      await pool.request()
        .input('id', sql.NVarChar(50), item.id)
        .input('user_id', sql.Int, req.user.id)
        .input('tgl_pembelian', sql.NVarChar(50), item.tgl_pembelian ?? null)
        .input('lokasi_beli', sql.NVarChar(255), item.lokasi_beli ?? null)
        .input('harga_beli', sql.Decimal(18,2), hargaBeli)
        .input('nama_kendaraan', sql.NVarChar(255), item.nama_kendaraan ?? null)
        .input('penomoran', sql.NVarChar(255), item.penomoran ?? null)
        .input('kategori_kendaraan', sql.NVarChar(255), item.kategori_kendaraan ?? null)
        .input('penomoran_kategori', sql.NVarChar(255), item.penomoran_kategori ?? null)
        .input('kode_hotwheel', sql.NVarChar(255), item.kode_hotwheel ?? null)
        .input('kendaraan', sql.NVarChar(50), item.kendaraan ?? null)
        .input('tahun_kendaraan', sql.Int, tahunKendaraan)
        .input('trackstar', sql.Bit, trackstar)
        .input('special_kategori', sql.NVarChar(255), item.special_kategori ?? null)
        .input('netflix', sql.Bit, netflix)
        .input('hotwheel_showdown', sql.Bit, hotwheelShowdown)
        .input('warna_1', sql.NVarChar(100), item.warna_1 ?? null)
        .input('warna_2', sql.NVarChar(100), item.warna_2 ?? null)
        .input('foto', sql.NVarChar(sql.MAX), item.foto ?? null)
        .query(`
          IF EXISTS (SELECT 1 FROM dbo.hotwheels_collection WHERE id = @id)
            UPDATE dbo.hotwheels_collection SET
              user_id = @user_id,
              tgl_pembelian = @tgl_pembelian,
              lokasi_beli = @lokasi_beli,
              harga_beli = @harga_beli,
              nama_kendaraan = @nama_kendaraan,
              penomoran = @penomoran,
              kategori_kendaraan = @kategori_kendaraan,
              penomoran_kategori = @penomoran_kategori,
              kode_hotwheel = @kode_hotwheel,
              kendaraan = @kendaraan,
              tahun_kendaraan = @tahun_kendaraan,
              trackstar = @trackstar,
              special_kategori = @special_kategori,
              netflix = @netflix,
              hotwheel_showdown = @hotwheel_showdown,
              warna_1 = @warna_1,
              warna_2 = @warna_2,
              foto = @foto
            WHERE id = @id
          ELSE
            INSERT INTO dbo.hotwheels_collection (
              id, user_id, tgl_pembelian, lokasi_beli, harga_beli,
              nama_kendaraan, penomoran, kategori_kendaraan, penomoran_kategori,
              kode_hotwheel, kendaraan, tahun_kendaraan, trackstar,
              special_kategori, netflix, hotwheel_showdown,
              warna_1, warna_2, foto
            ) VALUES (
              @id, @user_id, @tgl_pembelian, @lokasi_beli, @harga_beli,
              @nama_kendaraan, @penomoran, @kategori_kendaraan, @penomoran_kategori,
              @kode_hotwheel, @kendaraan, @tahun_kendaraan, @trackstar,
              @special_kategori, @netflix, @hotwheel_showdown,
              @warna_1, @warna_2, @foto
            );
        `);
    }

    res.json({ message: 'Sync berhasil' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/collections', authenticateToken, async (req, res) => {
  try {
    const pool = await poolPromise;
    const result = await pool.request()
      .input('user_id', sql.Int, req.user.id)
      .query('SELECT * FROM dbo.hotwheels_collection WHERE user_id = @user_id ORDER BY tgl_pembelian DESC');

    res.json(result.recordset);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/sync/delete', authenticateToken, async (req, res) => {
  try {
    const { ids } = req.body;
    if (!Array.isArray(ids) || ids.length === 0) {
      return res.status(400).json({ message: 'IDs must be a non-empty array' });
    }

    const pool = await poolPromise;
    const request = pool.request();
    request.input('user_id', sql.Int, req.user.id);

    const idParams = ids.map((id, index) => {
      const paramName = `id${index}`;
      request.input(paramName, sql.NVarChar(50), id);
      return `@${paramName}`;
    }).join(',');

    await request.query(`DELETE FROM dbo.hotwheels_collection WHERE user_id = @user_id AND id IN (${idParams})`);

    res.json({ message: 'Deletion sync successful' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message });
  }
});

app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

const port = process.env.PORT || 3000;
ensureDatabaseTables()
  .then(() => {
    app.listen(port, '0.0.0.0', () => console.log(`Server running on ${BASE_URL}`));
  })
  .catch(err => {
    console.error('Failed to initialize database:', err);
    process.exit(1);
  });