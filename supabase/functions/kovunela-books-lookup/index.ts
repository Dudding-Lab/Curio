// ISBN-only metadata lookup. The client must be signed in.
// This function does not create items, invoke models or store results.
const headers = {
  "Content-Type": "application/json; charset=utf-8",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Cache-Control": "no-store",
};
function respond(status: number, result: unknown): Response {
  return new Response(JSON.stringify(result), { status, headers });
}
function validIsbn(value: string): string | null {
  const isbn = value.replace(/[\s-]/g, "").toUpperCase();
  if (!/^(?:[0-9]{13}|[0-9]{9}[0-9X])$/.test(isbn)) return null;
  if (isbn.length === 13) {
    const sum = [...isbn].reduce((acc, digit, i) =>
      acc + Number(digit) * (i % 2 === 0 ? 1 : 3), 0);
    return sum % 10 === 0 ? isbn : null;
  }
  const sum = [...isbn].reduce((acc, digit, i) =>
    acc + (10 - i) * (digit === "X" ? 10 : Number(digit)), 0);
  return sum % 11 === 0 ? isbn : null;
}
Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers });
  if (req.method !== "POST") return respond(405, { error: "method_not_allowed" });
  try {
    const authorization = req.headers.get("Authorization") ?? "";
    if (!/^Bearer\s+\S+$/i.test(authorization)) {
      return respond(401, { error: "authentication_required" });
    }
    // Verify the JWT with the actual Auth service instead of trusting claims.
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    if (!supabaseUrl || !anonKey) return respond(503, { error: "auth_unavailable" });
    const authResponse = await fetch(supabaseUrl + "/auth/v1/user", {
      headers: { Authorization: authorization, apikey: anonKey },
      signal: AbortSignal.timeout(7000),
    });
    if (!authResponse.ok) return respond(401, { error: "authentication_required" });
    const user = await authResponse.json();
    if (typeof user.id !== "string") return respond(401, { error: "authentication_required" });

    const body = await req.json();
    if (!body || typeof body !== "object" || Array.isArray(body) ||
      typeof body.isbn !== "string" || body.isbn.length > 64) {
      return respond(400, { error: "invalid_isbn" });
    }
    const isbn = validIsbn(body.isbn);
    if (isbn === null) return respond(400, { error: "invalid_isbn" });

    const query = new URL("https://www.googleapis.com/books/v1/volumes");
    query.searchParams.set("q", "isbn:" + isbn);
    query.searchParams.set("maxResults", "5");
    query.searchParams.set("printType", "books");
    const googleKey = Deno.env.get("GOOGLE_BOOKS_API_KEY");
    if (googleKey) query.searchParams.set("key", googleKey);
    const result = await fetch(query.toString(), {
      headers: { Accept: "application/json" },
      signal: AbortSignal.timeout(8000),
    });
    if (!result.ok) {
      return respond(result.status === 429 ? 429 : 502, {
        error: "catalog_unavailable",
      });
    }
    const json = await result.json();
    const items = Array.isArray(json.items) ? json.items.slice(0, 5) : [];
    const books = items.flatMap((volume: any) => {
      const info = volume?.volumeInfo;
      if (!info || typeof info.title !== "string") return [];
      const ids = Array.isArray(info.industryIdentifiers)
        ? info.industryIdentifiers : [];
      const exact = ids.some((v: any) => typeof v.identifier === "string" &&
        v.identifier.replace(/[\s-]/g, "").toUpperCase() === isbn);
      if (!exact) return [];
      const rawDate = typeof info.publishedDate === "string" ? info.publishedDate : "";
      const year = /^\d{4}/.test(rawDate) ? Number(rawDate.slice(0, 4)) : null;
      const authors = Array.isArray(info.authors)
        ? info.authors.filter((a: unknown) => typeof a === "string").slice(0, 5) : [];
      return [{
        source: "google_books",
        source_id: typeof volume.id === "string" ? volume.id : "",
        title: info.title.slice(0, 200),
        attributes: {
          ...(authors.length > 0 ? { author: authors.join(", ").slice(0, 600) } : {}),
          isbn,
          ...(typeof info.publisher === "string"
            ? { publisher: info.publisher.slice(0, 500) } : {}),
          ...(year !== null ? { publication_year: year } : {}),
          ...(typeof info.language === "string"
            ? { language: info.language.slice(0, 20) } : {}),
        },
        evidence: {
          isbn: "Google Books exact ISBN match",
        },
      }];
    });
    return respond(200, { isbn, books, source: "google_books" });
  } catch (_) {
    return respond(502, { error: "lookup_failed" });
  }
});
