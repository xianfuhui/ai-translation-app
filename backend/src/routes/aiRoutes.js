const express = require('express');
const router = express.Router();
const { chat, summarize, getConversations, getConversationById } = require('../controllers/aiController');
const { protect } = require('../middleware/auth');

router.use(protect); // Mobile only

router.post('/chat', chat);
router.post('/summarize/:conversationId', summarize);
router.get('/conversations', getConversations);
router.get('/conversations/:id', getConversationById);

module.exports = router;
