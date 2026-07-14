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

// Counter endpoint
app.get("/counter", async (req, res) => {
  const query = "SELECT COUNT(*) FROM swaps";
  const result = await pool.query(query);
  res.json(result.rows[0]);
});

// Save offer endpoint
app.post("/save-offer", async (req, res) => {
  const {
    name,
    email,
    skill_teaching,
    skill_learning,
    timezone,
    availability,
  } = req.body;
  const query =
    "INSERT INTO offers (name, email, skill_teaching, skill_learning, timezone, availability) VALUES ($1, $2, $3, $4, $5, $6)";
  await pool.query(query, [
    name,
    email,
    skill_teaching,
    skill_learning,
    timezone,
    JSON.stringify(availability),
  ]);
  res.json({ success: true });
});

// Save match request endpoint
app.post("/api/match", async (req, res) => {
  const { offer, filters } = req.body;
  // Implement match logic here
  res.json({ success: true });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
