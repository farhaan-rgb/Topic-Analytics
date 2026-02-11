(function () {
  const url = (window.TEACHMINT_SUPABASE_URL || "").trim();
  const anonKey = (window.TEACHMINT_SUPABASE_ANON_KEY || "").trim();

  function isConfigured() {
    return Boolean(url && anonKey && window.supabase && typeof window.supabase.createClient === "function");
  }

  let client = null;

  function getClient() {
    if (!isConfigured()) {
      throw new Error("Supabase is not configured. Set TEACHMINT_SUPABASE_URL and TEACHMINT_SUPABASE_ANON_KEY in supabase-config.js");
    }
    if (!client) {
      client = window.supabase.createClient(url, anonKey);
    }
    return client;
  }

  function uniqueIntArray(arr) {
    return [...new Set((Array.isArray(arr) ? arr : []).map((v) => Number(v)).filter((v) => Number.isInteger(v) && v >= 0))];
  }

  function normalizeTimeMap(obj) {
    if (!obj || typeof obj !== "object") return {};
    const out = {};
    for (const [k, v] of Object.entries(obj)) {
      const n = Number(v);
      if (Number.isFinite(n) && n >= 0) out[String(k)] = Math.round(n);
    }
    return out;
  }

  function normalizeProgressRow(row) {
    const source = row && typeof row === "object" ? row : {};
    return {
      practice_attempted: uniqueIntArray(source.practice_attempted),
      practice_correct: uniqueIntArray(source.practice_correct),
      practice_first_try_correct: uniqueIntArray(source.practice_first_try_correct),
      practice_time_ms_by_question: normalizeTimeMap(source.practice_time_ms_by_question),
      review_attempted: uniqueIntArray(source.review_attempted),
      review_first_try_correct: uniqueIntArray(source.review_first_try_correct),
      review_time_ms_by_question: normalizeTimeMap(source.review_time_ms_by_question)
    };
  }

  async function getCurrentUser() {
    const supa = getClient();
    const { data, error } = await supa.auth.getUser();
    if (error) throw error;
    return data.user || null;
  }

  async function signOut() {
    const supa = getClient();
    const { error } = await supa.auth.signOut();
    if (error) throw error;
  }

  async function signInOrCreate(email, password) {
    const supa = getClient();

    const signInRes = await supa.auth.signInWithPassword({ email, password });
    if (!signInRes.error && signInRes.data && signInRes.data.user) {
      return { ok: true, created: false, user: signInRes.data.user };
    }

    const signUpRes = await supa.auth.signUp({ email, password });
    if (signUpRes.error) {
      const msg = String(signUpRes.error.message || "").toLowerCase();
      if (msg.includes("already") || msg.includes("registered") || msg.includes("exists")) {
        return { ok: false, reason: "wrong_password", error: signUpRes.error };
      }
      return { ok: false, reason: "signup_failed", error: signUpRes.error };
    }

    const user = signUpRes.data && signUpRes.data.user ? signUpRes.data.user : null;
    if (!user) {
      return { ok: false, reason: "signup_failed", error: new Error("Unable to create account.") };
    }

    if (!signUpRes.data.session) {
      return {
        ok: false,
        reason: "email_confirmation_required",
        error: new Error("Email confirmation is enabled. Disable it in Supabase Auth settings for this flow.")
      };
    }

    return { ok: true, created: true, user };
  }

  async function listFiles(userId) {
    const supa = getClient();
    const { data, error } = await supa
      .from("files")
      .select("id,name,uploaded_at,text_content,questions")
      .eq("user_id", userId)
      .order("uploaded_at", { ascending: false });
    if (error) throw error;
    return Array.isArray(data) ? data : [];
  }

  async function getFileById(userId, fileId) {
    const supa = getClient();
    const { data, error } = await supa
      .from("files")
      .select("id,name,uploaded_at,text_content,questions")
      .eq("user_id", userId)
      .eq("id", fileId)
      .maybeSingle();
    if (error) throw error;
    return data || null;
  }

  async function createFile(userId, payload) {
    const supa = getClient();
    const { data, error } = await supa
      .from("files")
      .insert({
        id: payload.id,
        user_id: userId,
        name: payload.name,
        uploaded_at: payload.uploaded_at,
        text_content: payload.text_content,
        questions: payload.questions
      })
      .select("id,name,uploaded_at,text_content,questions")
      .single();
    if (error) throw error;
    return data;
  }

  async function getProgress(userId, fileId) {
    const supa = getClient();
    const { data, error } = await supa
      .from("file_progress")
      .select("file_id,practice_attempted,practice_correct,practice_first_try_correct,practice_time_ms_by_question,review_attempted,review_first_try_correct,review_time_ms_by_question")
      .eq("user_id", userId)
      .eq("file_id", fileId)
      .maybeSingle();
    if (error) throw error;
    return data ? { ...data, ...normalizeProgressRow(data) } : null;
  }

  async function listProgressForFiles(userId, fileIds) {
    const ids = Array.isArray(fileIds) ? fileIds.filter(Boolean) : [];
    if (!ids.length) return [];
    const supa = getClient();
    const { data, error } = await supa
      .from("file_progress")
      .select("file_id,practice_attempted,practice_correct,practice_first_try_correct,practice_time_ms_by_question,review_attempted,review_first_try_correct,review_time_ms_by_question")
      .eq("user_id", userId)
      .in("file_id", ids);
    if (error) throw error;
    return (Array.isArray(data) ? data : []).map((row) => ({ ...row, ...normalizeProgressRow(row) }));
  }

  async function upsertProgress(userId, fileId, patch) {
    const existing = (await getProgress(userId, fileId)) || { file_id: fileId };
    const merged = normalizeProgressRow({ ...existing, ...(patch || {}) });
    const supa = getClient();
    const { data, error } = await supa
      .from("file_progress")
      .upsert({
        user_id: userId,
        file_id: fileId,
        ...merged,
        updated_at: new Date().toISOString()
      }, { onConflict: "user_id,file_id" })
      .select("file_id,practice_attempted,practice_correct,practice_first_try_correct,practice_time_ms_by_question,review_attempted,review_first_try_correct,review_time_ms_by_question")
      .single();
    if (error) throw error;
    return { ...data, ...normalizeProgressRow(data) };
  }

  window.teachmintApi = {
    isConfigured,
    getCurrentUser,
    signInOrCreate,
    signOut,
    listFiles,
    getFileById,
    createFile,
    getProgress,
    listProgressForFiles,
    upsertProgress
  };
})();
