const express = require("express");
const axios = require("axios");
const { Pool } = require("pg");

const app = express();
app.use(express.json());

const pool = new Pool({
  user: "de0gratius420@gmail.com",
  host: "localhost",
  database: "skillswap",
  password: "your-password",
  port: 5432,
});

// Fetch offers endpoint
app.get("/api/offers", async (req, res) => {
  const query =
    "SELECT * FROM offers WHERE is_matched = false ORDER BY created_at DESC";
  const result = await pool.query(query);
  res.json(result.rows);
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
