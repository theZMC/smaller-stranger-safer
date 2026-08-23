require("dotenv").config();

const express = require("express");
const pino = require("pino");

const log = pino();
const app = express();
const port = process.env.PORT || 3000;

const orders = [
  { id: 1, item: "widget", qty: 3, status: "shipped" },
  { id: 2, item: "sprocket", qty: 12, status: "pending" },
  { id: 3, item: "flange", qty: 1, status: "delivered" },
];

app.get("/healthz", (req, res) => {
  res.json({ ok: true });
});

app.get("/orders", (req, res) => {
  log.info("listing orders");
  res.json(orders);
});

app.listen(port, () => {
  log.info(`orders-api listening on ${port}`);
});
