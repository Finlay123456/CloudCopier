// src/middleware/auth.js

require('dotenv').config();

function requireApiKey(req, res, next) {
	const apiKey = req.headers['x-api-key'];
	if(!apiKey || apiKey !== process.env.API_KEY) {
		return res.status(401).json({ error: 'Unauthorized' });
	}
	next();
}

module.exports = { requireApiKey };
