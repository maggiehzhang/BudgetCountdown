require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { PlaidApi, PlaidEnvironments, Configuration, Products, CountryCode } = require('plaid');

const app = express();
app.use(cors());
app.use(express.json());

const plaidConfig = new Configuration({
  basePath: PlaidEnvironments[process.env.PLAID_ENV || 'sandbox'],
  baseOptions: {
    headers: {
      'PLAID-CLIENT-ID': process.env.PLAID_CLIENT_ID,
      'PLAID-SECRET': process.env.PLAID_SECRET,
    },
  },
});
const plaidClient = new PlaidApi(plaidConfig);

// Returns the start date of the current Chase billing period (24th of each month)
function getBillingPeriodStart() {
  const today = new Date();
  const day = today.getDate();
  if (day >= 24) {
    return new Date(today.getFullYear(), today.getMonth(), 24);
  } else {
    const lastMonth = new Date(today.getFullYear(), today.getMonth() - 1, 24);
    return lastMonth;
  }
}

function formatDate(date) {
  return date.toISOString().split('T')[0]; // YYYY-MM-DD
}

// Step 1: App calls this to get a token to launch Plaid Link
app.post('/link-token', async (req, res) => {
  try {
    const params = {
      user: { client_user_id: 'budget-app-user' },
      client_name: 'Budget Countdown',
      products: [Products.Transactions],
      country_codes: [CountryCode.Us],
      language: 'en',
    };
    // Required for OAuth banks (e.g. Chase) in production. Must exactly match a
    // redirect URI registered in the Plaid Dashboard. Omit it in sandbox.
    if (process.env.PLAID_REDIRECT_URI) {
      params.redirect_uri = process.env.PLAID_REDIRECT_URI;
    }
    const response = await plaidClient.linkTokenCreate(params);
    res.json({ link_token: response.data.link_token });
  } catch (err) {
    console.error('link-token error:', err.response?.data || err.message);
    res.status(500).json({ error: err.message });
  }
});

// Step 2: After user links Chase, app sends the public_token here to exchange for an access token
// The access token is printed — you then paste it into Railway as PLAID_ACCESS_TOKEN env var
app.post('/exchange-token', async (req, res) => {
  const { public_token } = req.body;
  if (!public_token) return res.status(400).json({ error: 'public_token required' });

  try {
    const response = await plaidClient.itemPublicTokenExchange({ public_token });
    const accessToken = response.data.access_token;

    console.log('\n✅ Chase linked successfully!');
    console.log('Copy this access token and set it as PLAID_ACCESS_TOKEN in Railway:\n');
    console.log(accessToken);
    console.log('\n');

    res.json({ success: true, access_token: accessToken });
  } catch (err) {
    console.error('exchange-token error:', err.response?.data || err.message);
    res.status(500).json({ error: err.message });
  }
});

// Step 3: App calls this on every open to get current billing period transactions
app.get('/transactions', async (req, res) => {
  const accessToken = process.env.PLAID_ACCESS_TOKEN;
  if (!accessToken) {
    return res.status(503).json({ error: 'Chase not linked yet. Complete setup first.' });
  }

  const periodStart = getBillingPeriodStart();
  const today = new Date();

  try {
    const response = await plaidClient.transactionsGet({
      access_token: accessToken,
      start_date: formatDate(periodStart),
      end_date: formatDate(today),
      options: { count: 500 },
    });

    const transactions = response.data.transactions
      .map(t => ({
        id: t.transaction_id,
        date: t.date,
        name: t.name,
        amount: t.amount,
        category: t.personal_finance_category?.primary || null,
        pending: t.pending,
      }));

    const totalSpent = transactions
      .filter(t => t.amount > 0)
      .reduce((sum, t) => sum + t.amount, 0);

    res.json({
      periodStart: formatDate(periodStart),
      periodEnd: formatDate(new Date(periodStart.getFullYear(), periodStart.getMonth() + 1, 23)),
      transactions,
      totalSpent: Math.round(totalSpent * 100) / 100,
    });
  } catch (err) {
    console.error('transactions error:', err.response?.data || err.message);
    res.status(500).json({ error: err.message });
  }
});

app.get('/health', (req, res) => res.json({ ok: true }));
app.get('/oauth-redirect', (req, res) => res.send('Redirecting back to app...'));

// Debug: returns all transactions from the past 2 years regardless of billing period
app.get('/debug/all-transactions', async (req, res) => {
  const accessToken = process.env.PLAID_ACCESS_TOKEN;
  if (!accessToken) return res.status(503).json({ error: 'Not linked' });
  try {
    const response = await plaidClient.transactionsGet({
      access_token: accessToken,
      start_date: '2024-01-01',
      end_date: formatDate(new Date()),
      options: { count: 10 },
    });
    res.json({
      total: response.data.total_transactions,
      sample: response.data.transactions.map(t => ({ date: t.date, name: t.name, amount: t.amount })),
    });
  } catch (err) {
    res.status(500).json({ error: err.response?.data || err.message });
  }
});

// Sandbox only — fires a webhook to generate fresh transactions with today's date
app.post('/sandbox/generate-transactions', async (req, res) => {
  try {
    await plaidClient.sandboxItemFireWebhook({
      access_token: process.env.PLAID_ACCESS_TOKEN,
      webhook_code: 'DEFAULT_UPDATE',
    });
    res.json({ ok: true, message: 'Webhook fired — transactions generating' });
  } catch (err) {
    res.status(500).json({ error: err.response?.data || err.message });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Budget backend running on port ${PORT}`));
