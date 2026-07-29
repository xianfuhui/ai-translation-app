const express = require('express');
const router = express.Router();
const apiClient = require('../services/apiClient');
const { requireAuth } = require('../middleware/requireAuth');

router.get('/dashboard', requireAuth, async (req, res, next) => {
  try {
    const client = apiClient(req);
    const [userStatsRes, vocabStatsRes] = await Promise.all([
      client.get('/stats/users'),
      client.get('/stats/vocabulary'),
    ]);

    res.render('dashboard', {
      userStats: userStatsRes.data,
      vocabStats: vocabStatsRes.data,
    });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
