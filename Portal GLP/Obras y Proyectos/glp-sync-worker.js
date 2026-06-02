/**
 * GLP Control de Obras — Cloudflare Worker (Sync API)
 * Almacena y sirve los datos compartidos usando Cloudflare KV.
 *
 * Variables de entorno requeridas:
 *   GLP_KV    → KV Namespace (configurado en wrangler.toml o Dashboard)
 *   GLP_TOKEN → Token secreto para autorizar escrituras (ej: "GLP_SYNC_2026")
 */

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, PUT, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

export default {
  async fetch(request, env) {
    // Preflight CORS
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: CORS });
    }

    const KV_KEY = 'glp_data';

    // ── GET: leer datos ──────────────────────────────────────────────────────
    if (request.method === 'GET') {
      const data = await env.GLP_KV.get(KV_KEY);
      return new Response(data || '{}', {
        headers: { 'Content-Type': 'application/json', ...CORS },
      });
    }

    // ── PUT: guardar datos (requiere token) ──────────────────────────────────
    if (request.method === 'PUT') {
      const authHeader = request.headers.get('Authorization') || '';
      const token = authHeader.replace('Bearer ', '').trim();

      if (!env.GLP_TOKEN || token !== env.GLP_TOKEN) {
        return new Response(JSON.stringify({ error: 'No autorizado' }), {
          status: 401,
          headers: { 'Content-Type': 'application/json', ...CORS },
        });
      }

      const body = await request.text();

      // Validar que sea JSON válido antes de guardar
      try { JSON.parse(body); } catch {
        return new Response(JSON.stringify({ error: 'JSON inválido' }), {
          status: 400,
          headers: { 'Content-Type': 'application/json', ...CORS },
        });
      }

      await env.GLP_KV.put(KV_KEY, body);

      return new Response(JSON.stringify({ ok: true, ts: new Date().toISOString() }), {
        headers: { 'Content-Type': 'application/json', ...CORS },
      });
    }

    return new Response('Método no permitido', { status: 405, headers: CORS });
  },
};
