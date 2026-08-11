require("dotenv").config();
const express = require("express");
const cors = require("cors");
const bcrypt = require("bcrypt");
const jwt = require("jsonwebtoken");
const sql = require("mssql");
const https = require("https");
const http = require("http");
const fs = require("fs");
const path = require("path");
const os = require("os");
const selfsigned = require("selfsigned");

const app = express();

// --- CONFIGURATION ---
const PORT = process.env.PORT || 3000;
const JWT_SECRET = process.env.JWT_SECRET || "rahasia_super_aman_123";
const DEBUG_MODE = process.env.DEBUG_MODE === 'true';

// Folder untuk hasil build Flutter Web
const PUBLIC_DIR = path.join(__dirname, "public");
const CERT_DIR = path.join(__dirname, "cert");

// --- SSL GENERATION ---
async function ensureCertificates() {
  if (!fs.existsSync(CERT_DIR)) {
    fs.mkdirSync(CERT_DIR, { recursive: true });
  }

  const keyFile = path.join(CERT_DIR, "key.pem");
  const certFile = path.join(CERT_DIR, "cert.pem");

  if (fs.existsSync(keyFile) && fs.existsSync(certFile)) {
    return {
      key: fs.readFileSync(keyFile),
      cert: fs.readFileSync(certFile),
    };
  }

  console.log("\x1b[33m%s\x1b[0m", "[SSL] 🔑 Generating self-signed certificates...");

  const networkInterfaces = os.networkInterfaces();
  let localIp = "localhost";
  for (const interfaces of Object.values(networkInterfaces)) {
    if (!interfaces) continue;
    for (const iface of interfaces) {
      if (iface && iface.family === "IPv4" && !iface.internal) {
        localIp = iface.address;
        break;
      }
    }
    if (localIp !== "localhost") break;
  }

  const attrs = [{ name: "commonName", value: localIp }];
  const pems = await selfsigned.generate(attrs, { days: 365, keySize: 2048 });

  fs.writeFileSync(keyFile, pems.private);
  fs.writeFileSync(certFile, pems.cert);

  console.log("\x1b[32m%s\x1b[0m", `[SSL] ✅ Certificates generated for ${localIp}`);

  return {
    key: Buffer.from(pems.private),
    cert: Buffer.from(pems.cert),
  };
}

// --- MIDDLEWARE ---
app.use(cors({
  origin: "*",
  methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
  allowedHeaders: ["Content-Type", "Authorization"],
  preflightContinue: false,
  optionsSuccessStatus: 204,
}));
app.use(express.json({ limit: "50mb" }));

if (!fs.existsSync(PUBLIC_DIR)) {
  fs.mkdirSync(PUBLIC_DIR);
}
app.use(express.static(PUBLIC_DIR));

// --- DATABASE CONFIG ---
const dbConfig = {
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  server: process.env.DB_SERVER,
  database: process.env.DB_NAME,
  port: process.env.DB_PORT ? parseInt(process.env.DB_PORT, 10) : 1433,
  options: { encrypt: false, trustServerCertificate: true },
};

const poolPromise = new sql.ConnectionPool(dbConfig).connect();

// --- AUTH MIDDLEWARE ---
const authenticateToken = (req, res, next) => {
  if (DEBUG_MODE) {
    req.user = { id: 1, username: 'DEBUG_USER' };
    return next();
  }

  const authHeader = req.headers["authorization"];
  const token = authHeader && authHeader.split(" ")[1];
  if (!token) return res.status(401).json({ message: "Token tidak ditemukan" });

  jwt.verify(token, JWT_SECRET, (err, user) => {
    if (err) return res.status(403).json({ message: "Token tidak valid" });
    req.user = user;
    next();
  });
};

// --- DATABASE TABLES ---
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
        penomoran_1 NVARCHAR(50),
        penomoran_2 NVARCHAR(50),
        kategori_kendaraan NVARCHAR(255),
        penomoran_kategori_1 NVARCHAR(50),
        penomoran_kategori_2 NVARCHAR(50),
        kode_hotwheel NVARCHAR(255),
        kendaraan NVARCHAR(50),
        jenis_kendaraan NVARCHAR(100),
        tahun_kendaraan INT NULL,
        trackstar BIT DEFAULT 0,
        special_kategori NVARCHAR(255),
        netflix BIT DEFAULT 0,
        hotwheel_showdown BIT DEFAULT 0,
        warna_1 NVARCHAR(100) NOT NULL,
        warna_2 NVARCHAR(100),
        warna_3 NVARCHAR(100),
        foto NVARCHAR(MAX) NULL,
        updated_at NVARCHAR(50),
        created_at NVARCHAR(50),
        photo_updated_at NVARCHAR(50)
      );
    END
    ELSE
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.hotwheels_collection') AND name = 'warna_3')
        ALTER TABLE dbo.hotwheels_collection ADD warna_3 NVARCHAR(100);
      IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.hotwheels_collection') AND name = 'penomoran_1')
        ALTER TABLE dbo.hotwheels_collection ADD penomoran_1 NVARCHAR(50);
      IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.hotwheels_collection') AND name = 'penomoran_2')
        ALTER TABLE dbo.hotwheels_collection ADD penomoran_2 NVARCHAR(50);
      IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.hotwheels_collection') AND name = 'penomoran_kategori_1')
        ALTER TABLE dbo.hotwheels_collection ADD penomoran_kategori_1 NVARCHAR(50);
      IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.hotwheels_collection') AND name = 'penomoran_kategori_2')
        ALTER TABLE dbo.hotwheels_collection ADD penomoran_kategori_2 NVARCHAR(50);
      IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.hotwheels_collection') AND name = 'jenis_kendaraan')
        ALTER TABLE dbo.hotwheels_collection ADD jenis_kendaraan NVARCHAR(100);
      IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.hotwheels_collection') AND name = 'updated_at')
        ALTER TABLE dbo.hotwheels_collection ADD updated_at NVARCHAR(50);
      IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.hotwheels_collection') AND name = 'created_at')
        ALTER TABLE dbo.hotwheels_collection ADD created_at NVARCHAR(50);
      IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.hotwheels_collection') AND name = 'photo_updated_at')
        ALTER TABLE dbo.hotwheels_collection ADD photo_updated_at NVARCHAR(50);
    END
  `);
}

app.get('/api/health', (req, res) => {
  res.status(200).json({ success: true, message: 'Hotwheels API is running', timestamp: new Date().toISOString() });
});

app.post("/register", async (req, res) => {
  try {
    const { username, password } = req.body;
    if (!username || !password) return res.status(400).json({ message: "Username dan password wajib diisi" });
    const pool = await poolPromise;
    const existing = await pool.request().input("username", sql.NVarChar(100), username).query("SELECT TOP 1 id FROM dbo.users WHERE username = @username");
    if (existing.recordset.length > 0) return res.status(409).json({ message: "Username sudah digunakan" });
    const hashedPassword = await bcrypt.hash(password, 10);
    await pool.request().input("username", sql.NVarChar(100), username).input("password_hash", sql.NVarChar(255), hashedPassword).query("INSERT INTO dbo.users (username, password_hash) VALUES (@username, @password_hash)");
    res.status(201).json({ message: "User berhasil dibuat" });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

app.post("/login", async (req, res) => {
  try {
    const { username, password } = req.body;
    if (!username || !password) return res.status(400).json({ message: "Username dan password wajib diisi" });
    const pool = await poolPromise;
    const result = await pool.request().input("username", sql.NVarChar(100), username).query("SELECT TOP 1 * FROM dbo.users WHERE username = @username");
    const user = result.recordset[0];
    if (!user || !(await bcrypt.compare(password, user.password_hash))) return res.status(401).json({ message: "Username atau password salah" });
    const token = jwt.sign({ id: user.id, username: user.username }, JWT_SECRET, { expiresIn: "24h" });
    res.json({ token, userId: user.id, message: "Login berhasil" });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

app.post("/api/sync", authenticateToken, async (req, res) => {
  try {
    const data = Array.isArray(req.body) ? req.body : [];
    const pool = await poolPromise;
    for (let item of data) {
      const trackstar = item.trackstar ? 1 : 0;
      const netflix = item.netflix ? 1 : 0;
      const hotwheel_showdown = item.hotwheel_showdown ? 1 : 0;
      const hargaBeli = item.harga_beli !== undefined && item.harga_beli !== null ? parseFloat(item.harga_beli) : null;
      const tahunKendaraan = item.tahun_kendaraan !== undefined && item.tahun_kendaraan !== null ? parseInt(item.tahun_kendaraan, 10) : null;

      await pool.request()
        .input("id", sql.NVarChar(50), item.id)
        .input("user_id", sql.Int, req.user.id)
        .input("tgl_pembelian", sql.NVarChar(50), item.tgl_pembelian ?? null)
        .input("lokasi_beli", sql.NVarChar(255), item.lokasi_beli ?? null)
        .input("harga_beli", sql.Decimal(18, 2), hargaBeli)
        .input("nama_kendaraan", sql.NVarChar(255), item.nama_kendaraan ?? null)
        .input("penomoran_1", sql.NVarChar(50), item.penomoran_1 ?? null)
        .input("penomoran_2", sql.NVarChar(50), item.penomoran_2 ?? null)
        .input("kategori_kendaraan", sql.NVarChar(255), item.kategori_kendaraan ?? null)
        .input("penomoran_kategori_1", sql.NVarChar(50), item.penomoran_kategori_1 ?? null)
        .input("penomoran_kategori_2", sql.NVarChar(50), item.penomoran_kategori_2 ?? null)
        .input("kode_hotwheel", sql.NVarChar(255), item.kode_hotwheel ?? null)
        .input("kendaraan", sql.NVarChar(50), item.kendaraan ?? null)
        .input("jenis_kendaraan", sql.NVarChar(100), item.jenis_kendaraan ?? null)
        .input("tahun_kendaraan", sql.Int, tahunKendaraan)
        .input("trackstar", sql.Bit, trackstar)
        .input("special_kategori", sql.NVarChar(255), item.special_kategori ?? null)
        .input("netflix", sql.Bit, netflix)
        .input("hotwheel_showdown", sql.Bit, hotwheel_showdown)
        .input("warna_1", sql.NVarChar(100), item.warna_1 ?? null)
        .input("warna_2", sql.NVarChar(100), item.warna_2 ?? null)
        .input("warna_3", sql.NVarChar(100), item.warna_3 ?? null)
        .input("updated_at", sql.NVarChar(50), item.updated_at ?? null)
        .input("created_at", sql.NVarChar(50), item.created_at ?? null)
        .input("photo_updated_at", sql.NVarChar(50), item.photo_updated_at ?? null)
        .input("foto", sql.NVarChar(sql.MAX), item.foto ?? null).query(`
          IF EXISTS (SELECT 1 FROM dbo.hotwheels_collection WHERE id = @id)
            UPDATE dbo.hotwheels_collection SET
              user_id = @user_id, tgl_pembelian = @tgl_pembelian, lokasi_beli = @lokasi_beli, harga_beli = @harga_beli,
              nama_kendaraan = @nama_kendaraan, penomoran_1 = @penomoran_1, penomoran_2 = @penomoran_2,
              kategori_kendaraan = @kategori_kendaraan, penomoran_kategori_1 = @penomoran_kategori_1, penomoran_kategori_2 = @penomoran_kategori_2,
              kode_hotwheel = @kode_hotwheel, kendaraan = @kendaraan, jenis_kendaraan = @jenis_kendaraan, tahun_kendaraan = @tahun_kendaraan,
              trackstar = @trackstar, special_kategori = @special_kategori, netflix = @netflix, hotwheel_showdown = @hotwheel_showdown,
              warna_1 = @warna_1, warna_2 = @warna_2, warna_3 = @warna_3, updated_at = @updated_at, created_at = @created_at, photo_updated_at = @photo_updated_at, foto = @foto
            WHERE id = @id
          ELSE
            INSERT INTO dbo.hotwheels_collection (
              id, user_id, tgl_pembelian, lokasi_beli, harga_beli, nama_kendaraan, penomoran_1, penomoran_2,
              kategori_kendaraan, penomoran_kategori_1, penomoran_kategori_2, kode_hotwheel, kendaraan,
              jenis_kendaraan, tahun_kendaraan, trackstar, special_kategori, netflix, hotwheel_showdown,
              warna_1, warna_2, warna_3, updated_at, created_at, photo_updated_at, foto
            ) VALUES (
              @id, @user_id, @tgl_pembelian, @lokasi_beli, @harga_beli, @nama_kendaraan, @penomoran_1, @penomoran_2,
              @kategori_kendaraan, @penomoran_kategori_1, @penomoran_kategori_2, @kode_hotwheel, @kendaraan,
              @jenis_kendaraan, @tahun_kendaraan, @trackstar, @special_kategori, @netflix, @hotwheel_showdown,
              @warna_1, @warna_2, @warna_3, @updated_at, @created_at, @photo_updated_at, @foto
            );
        `);
    }
    res.json({ message: "Sync berhasil" });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

app.get("/api/collections", authenticateToken, async (req, res) => {
  try { 
    const pool = await poolPromise;
    const result = await pool.request().input("user_id", sql.Int, req.user.id).query("SELECT * FROM dbo.hotwheels_collection WHERE user_id = @user_id ORDER BY tgl_pembelian DESC");
    res.json(result.recordset);
  } catch (err) { res.status(500).json({ error: err.message }); }
});

app.get("/api/suggestions/:column", authenticateToken, async (req, res) => {
  try {
    const { column } = req.params;
    const allowedColumns = ["kategori_kendaraan", "special_kategori", "jenis_kendaraan", "warna_1", "warna_2", "warna_3", "lokasi_beli"];
    if (!allowedColumns.includes(column)) return res.status(400).json({ message: "Invalid column" });
    const pool = await poolPromise;
    const result = await pool.request().input("user_id", sql.Int, req.user.id).query(`SELECT DISTINCT ${column} FROM dbo.hotwheels_collection WHERE user_id = @user_id AND ${column} IS NOT NULL AND ${column} != ''`);
    res.json(result.recordset.map((row) => row[column]));
  } catch (err) { res.status(500).json({ error: err.message }); }
});

app.post("/api/sync/delete", authenticateToken, async (req, res) => {
  try {
    const { ids } = req.body;
    console.log(`[DEBUG] 🗑️  REQUEST DELETE: IDs: ${ids}`);

    if (!Array.isArray(ids) || ids.length === 0) {
      return res.status(400).json({ message: "IDs must be a non-empty array" });
    }

    const pool = await poolPromise;
    const request = pool.request();
    request.input("user_id", sql.Int, req.user.id);

    const idParams = ids.map((id, index) => {
      const name = `id${index}`;
      request.input(name, sql.NVarChar(50), id);
      return `@${name}`;
    }).join(",");

    const query = `DELETE FROM dbo.hotwheels_collection WHERE user_id = @user_id AND id IN (${idParams})`;
    console.log(`[DEBUG] 🛠️  SQL EXEC: ${query}`);

    const result = await request.query(query);
    console.log(`[DEBUG] ✅ SUCCESS: Deleted ${result.rowsAffected[0]} row(s).`);

    res.json({ message: "Deletion successful", affected: result.rowsAffected[0] });
  } catch (err) {
    console.error(`[DEBUG] 🚨 SERVER ERROR: ${err.message}`);
    res.status(500).json({ error: err.message });
  }
});

app.get("*any", (req, res) => {
  res.sendFile(path.join(PUBLIC_DIR, "index.html"), (err) => {
    if (err) res.status(404).send("Please build and copy Flutter Web to public/ folder");
  });
});

const startServer = async () => {
  try {
    await ensureDatabaseTables();

    const networkInterfaces = os.networkInterfaces();
    let localIp = 'localhost';
    for (const interfaces of Object.values(networkInterfaces)) {
      if (!interfaces) continue;
      for (const iface of interfaces) {
        if (iface && iface.family === 'IPv4' && !iface.internal) {
          localIp = iface.address;
          break;
        }
      }
      if (localIp !== 'localhost') break;
    }

    if (DEBUG_MODE) {
      // DEBUG MODE: Run on HTTP ONLY
      http.createServer(app).listen(PORT, '0.0.0.0', () => {
        console.log('\n==============================================');
        console.log('       HOTWHEELS SERVER (DEBUG HTTP)');
        console.log('==============================================');
        console.log(`🔓 Mode:    HTTP (Bypass SSL)`);
        console.log(`🚀 API:     http://${localIp}:${PORT}`);
        console.log('⚠️  Auth:    BYPASSED');
        console.log('==============================================\n');
      });
    } else {
      // PRODUCTION MODE: Run on HTTPS ONLY
      const sslOptions = await ensureCertificates();
      https.createServer(sslOptions, app).listen(PORT, '0.0.0.0', () => {
        console.log('\n==============================================');
        console.log('       HOTWHEELS SERVER (PROD HTTPS)');
        console.log('==============================================');
        console.log(`🔐 Mode:    HTTPS (Secure)`);
        console.log(`🚀 API:     https://${localIp}:${PORT}`);
        console.log('==============================================\n');
      });
    }

  } catch (err) {
    console.error('Failed to initialize server:', err);
    process.exit(1);
  }
};

startServer();
