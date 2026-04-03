const express = require('express');
const sql = require('mssql');
const path = require('path');
const app = express();

app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// Configuración de conexión usando variables de entorno
const config = {
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    server: process.env.DB_SERVER, 
    database: process.env.DB_NAME,
    options: {
        encrypt: true, // Requerido para Azure SQL
        trustServerCertificate: false
    }
};

// Endpoint: Obtener todos los tickets
app.get('/api/tickets', async (req, res) => {
    try {
        let pool = await sql.connect(config);
        let result = await pool.request().query("SELECT * FROM Tickets ORDER BY id DESC");
        res.json(result.recordset);
    } catch (err) {
        console.error("Error en GET /api/tickets:", err);
        res.status(500).send(err.message);
    }
});

// Endpoint: Crear un nuevo ticket
app.post('/api/tickets', async (req, res) => {
    try {
        const { usuario, asunto, prioridad } = req.body;
        let pool = await sql.connect(config);
        await pool.request()
            .input('u', sql.VarChar, usuario)
            .input('a', sql.VarChar, asunto)
            .input('p', sql.VarChar, prioridad)
            .query("INSERT INTO Tickets (usuario, asunto, prioridad, estado) VALUES (@u, @a, @p, 'Abierto')");
        res.sendStatus(201);
    } catch (err) {
        console.error("Error en POST /api/tickets:", err);
        res.status(500).send(err.message);
    }
});

// Servir el index.html para cualquier otra ruta
app.get('*', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`Servidor de tickets activo en puerto ${PORT}`);
});