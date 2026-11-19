// Same-origin proxy for the JioSaavn catalog API.
//
// The Flutter web build runs inside the browser, and www.jiosaavn.com/api.php
// sends no CORS headers, so direct calls from the page are blocked. This
// endpoint forwards the query to the upstream API server-side and returns the
// JSON, which makes the catalog work on the deployed site while the mobile
// builds keep calling the API directly.

const UPSTREAM = 'https://www.jiosaavn.com/api.php';

const UPSTREAM_HEADERS = {
  'User-Agent':
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  Accept: 'application/json, text/plain, */*',
  Referer: 'https://www.jiosaavn.com/',
};

module.exports = async function handler(req, res) {
  try {
    const params = new URLSearchParams();
    const incoming = req.query || {};

    for (const key of Object.keys(incoming)) {
      const value = incoming[key];
      if (Array.isArray(value)) {
        for (const item of value) params.append(key, String(item));
      } else if (value !== undefined && value !== null) {
        params.append(key, String(value));
      }
    }

    if (!params.has('_format')) params.set('_format', 'json');
    if (!params.has('_marker')) params.set('_marker', '0');
    if (!params.has('cc')) params.set('cc', 'in');

    const upstream = await fetch(`${UPSTREAM}?${params.toString()}`, {
      headers: UPSTREAM_HEADERS,
    });

    const body = await upstream.text();

    res.status(upstream.status);
    res.setHeader('Content-Type', 'application/json; charset=utf-8');
    res.setHeader('Cache-Control', 'public, s-maxage=300, stale-while-revalidate=600');
    res.send(body);
  } catch (error) {
    res.status(502).json({
      error: 'upstream_unreachable',
      message: String((error && error.message) || error),
    });
  }
};
