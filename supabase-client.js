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

  function normalizePercent(value) {
    const n = Number(value);
    if (!Number.isFinite(n)) return 0;
    return Math.max(0, Math.min(100, Math.round(n)));
  }

  function normalizeFeatureKey(value) {
    return String(value || "")
      .trim()
      .toLowerCase()
      .replace(/[^a-z0-9_]+/g, "_")
      .replace(/^_+|_+$/g, "");
  }

  function hashToBucket(input) {
    const text = String(input || "");
    let h = 2166136261;
    for (let i = 0; i < text.length; i += 1) {
      h ^= text.charCodeAt(i);
      h += (h << 1) + (h << 4) + (h << 7) + (h << 8) + (h << 24);
    }
    return Math.abs(h >>> 0) % 100;
  }

  function isUserInRollout(userId, percent) {
    const p = normalizePercent(percent);
    if (p <= 0) return false;
    if (p >= 100) return true;
    return hashToBucket(userId) < p;
  }

  async function getAbTestConfig(featureKey) {
    const key = normalizeFeatureKey(featureKey);
    if (!key) throw new Error("Feature key is required.");
    const supa = getClient();
    const { data, error } = await supa
      .from("ab_test_configs")
      .select("feature_key,test_percent,is_enabled,updated_at")
      .eq("feature_key", key)
      .maybeSingle();
    if (error) throw error;
    return data || null;
  }

  async function upsertAbTestConfig(featureKey, testPercent, enabled = true) {
    const key = normalizeFeatureKey(featureKey);
    if (!key) throw new Error("Feature key is required.");
    const supa = getClient();
    const { data, error } = await supa
      .from("ab_test_configs")
      .upsert({
        feature_key: key,
        test_percent: normalizePercent(testPercent),
        is_enabled: Boolean(enabled),
        updated_at: new Date().toISOString()
      }, { onConflict: "feature_key" })
      .select("feature_key,test_percent,is_enabled,updated_at")
      .single();
    if (error) throw error;
    return data;
  }

  async function getUserFeatureOverride(featureKey, userId) {
    const key = normalizeFeatureKey(featureKey);
    if (!key) throw new Error("Feature key is required.");
    if (!userId) throw new Error("User id is required.");
    const supa = getClient();
    const { data, error } = await supa
      .from("ab_user_features")
      .select("user_id,feature_key,is_enabled,updated_at")
      .eq("user_id", userId)
      .eq("feature_key", key)
      .maybeSingle();
    if (error) throw error;
    return data || null;
  }

  async function upsertUserFeatureOverride(userId, featureKey, isEnabled) {
    const key = normalizeFeatureKey(featureKey);
    if (!key) throw new Error("Feature key is required.");
    if (!userId) throw new Error("User id is required.");
    const supa = getClient();
    const { data, error } = await supa
      .from("ab_user_features")
      .upsert({
        user_id: userId,
        feature_key: key,
        is_enabled: Boolean(isEnabled),
        updated_at: new Date().toISOString()
      }, { onConflict: "user_id,feature_key" })
      .select("user_id,feature_key,is_enabled,updated_at")
      .single();
    if (error) throw error;
    return data;
  }

  async function isFeatureEnabledForUser(featureKey, userId, defaultPercent = 100) {
    const userOverride = await getUserFeatureOverride(featureKey, userId);
    if (userOverride) {
      return Boolean(userOverride.is_enabled);
    }
    const cfg = await getAbTestConfig(featureKey);
    if (!cfg) return isUserInRollout(userId, defaultPercent);
    if (!cfg.is_enabled) return false;
    return isUserInRollout(userId, cfg.test_percent);
  }

  async function isCurrentUserAdmin(userId) {
    const supa = getClient();
    const { data, error } = await supa
      .from("app_admins")
      .select("user_id")
      .eq("user_id", userId)
      .maybeSingle();
    if (error) throw error;
    return Boolean(data && data.user_id);
  }

  async function listAbFeatures(activeOnly = true) {
    const supa = getClient();
    let q = supa
      .from("ab_features")
      .select("feature_key,display_name,is_active,created_at,updated_at")
      .order("display_name", { ascending: true });
    if (activeOnly) {
      q = q.eq("is_active", true);
    }
    const { data, error } = await q;
    if (error) throw error;
    return Array.isArray(data) ? data : [];
  }

  async function upsertAbFeature(featureKey, displayName, isActive = true) {
    const key = normalizeFeatureKey(featureKey);
    const name = String(displayName || "").trim();
    if (!key) throw new Error("Feature key is required.");
    if (!name) throw new Error("Display name is required.");
    const supa = getClient();
    const { data, error } = await supa
      .from("ab_features")
      .upsert({
        feature_key: key,
        display_name: name,
        is_active: Boolean(isActive),
        updated_at: new Date().toISOString()
      }, { onConflict: "feature_key" })
      .select("feature_key,display_name,is_active,created_at,updated_at")
      .single();
    if (error) throw error;
    return data;
  }

  async function listSegmentParams(activeOnly = true) {
    const supa = getClient();
    let q = supa
      .from("ab_segment_params")
      .select("param_key,display_name,data_type,is_active,updated_at")
      .order("display_name", { ascending: true });
    if (activeOnly) {
      q = q.eq("is_active", true);
    }
    const { data, error } = await q;
    if (error) throw error;
    return Array.isArray(data) ? data : [];
  }

  async function applyAbSegmentRollout(featureKey, paramKey, operator, valueText, rolloutPercent, isEnabled = true) {
    const key = normalizeFeatureKey(featureKey);
    const param = String(paramKey || "").trim().toLowerCase();
    const op = String(operator || "").trim().toLowerCase();
    const value = String(valueText || "").trim();
    const pct = normalizePercent(rolloutPercent);
    if (!key) throw new Error("Feature key is required.");
    if (!param) throw new Error("Segment param is required.");
    if (!op) throw new Error("Operator is required.");
    if (!value) throw new Error("Value is required.");
    const supa = getClient();
    const { data, error } = await supa.rpc("apply_ab_segment_rollout", {
      p_feature_key: key,
      p_param_key: param,
      p_operator: op,
      p_value_text: value,
      p_rollout_percent: pct,
      p_is_enabled: Boolean(isEnabled)
    });
    if (error) throw error;
    return data || null;
  }

  async function getUserOnboarding(userId) {
    const supa = getClient();
    const { data, error } = await supa
      .from("user_onboarding")
      .select("user_id,exam_target,daily_practice_time,completed_at,updated_at")
      .eq("user_id", userId)
      .maybeSingle();
    if (error) throw error;
    return data || null;
  }

  async function upsertUserOnboarding(userId, patch) {
    const supa = getClient();
    const payload = {
      user_id: userId,
      exam_target: patch && patch.exam_target ? String(patch.exam_target) : null,
      daily_practice_time: patch && patch.daily_practice_time ? String(patch.daily_practice_time) : null,
      completed_at: patch && patch.completed_at ? patch.completed_at : null,
      updated_at: new Date().toISOString()
    };
    const { data, error } = await supa
      .from("user_onboarding")
      .upsert(payload, { onConflict: "user_id" })
      .select("user_id,exam_target,daily_practice_time,completed_at,updated_at")
      .single();
    if (error) throw error;
    return data;
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
    upsertProgress,
    getAbTestConfig,
    upsertAbTestConfig,
    getUserFeatureOverride,
    upsertUserFeatureOverride,
    isFeatureEnabledForUser,
    isUserInRollout,
    isCurrentUserAdmin,
    listAbFeatures,
    upsertAbFeature,
    listSegmentParams,
    applyAbSegmentRollout,
    getUserOnboarding,
    upsertUserOnboarding
  };
})();
