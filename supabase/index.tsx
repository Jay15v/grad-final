import { Hono } from "npm:hono";
import { cors } from "npm:hono/cors";
import { logger } from "npm:hono/logger";
import { createClient } from "npm:@supabase/supabase-js@2";
import * as kv from "./kv_store.tsx";

const app = new Hono();

// Initialize Supabase clients
const supabaseAdmin = createClient(
  Deno.env.get('SUPABASE_URL') ?? '',
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
);

const supabaseClient = createClient(
  Deno.env.get('SUPABASE_URL') ?? '',
  Deno.env.get('SUPABASE_ANON_KEY') ?? '',
);

// Enable logger
app.use('*', logger(console.log));

// Enable CORS for all routes and methods
app.use(
  "/*",
  cors({
    origin: "*",
    allowHeaders: ["Content-Type", "Authorization"],
    allowMethods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    exposeHeaders: ["Content-Length"],
    maxAge: 600,
  }),
);

// Health check endpoint
app.get("/make-server-d2949e14/health", (c) => {
  return c.json({ status: "ok" });
});

// Sign up endpoint
app.post("/make-server-d2949e14/signup", async (c) => {
  try {
    const { email, password, name, isAdmin } = await c.req.json();

    // Create user with Supabase Auth
    const { data, error } = await supabaseAdmin.auth.admin.createUser({
      email,
      password,
      user_metadata: { 
        name,
        role: isAdmin ? 'admin' : 'user'
      },
      // Automatically confirm the user's email since an email server hasn't been configured.
      email_confirm: true
    });

    if (error) {
      console.error('Sign up error:', error);
      return c.json({ error: error.message }, 400);
    }

    // Store user profile in KV store
    await kv.set(`user:${data.user.id}`, {
      id: data.user.id,
      email,
      name,
      role: isAdmin ? 'admin' : 'user',
      joinDate: new Date().toISOString(),
      stats: {
        analyzedPrompts: 0,
        blockedThreats: 0,
        allowedPrompts: 0,
        hesitateCases: 0
      }
    });

    return c.json({ 
      success: true, 
      user: {
        id: data.user.id,
        email: data.user.email,
        name,
        role: isAdmin ? 'admin' : 'user'
      }
    });
  } catch (error) {
    console.error('Sign up error:', error);
    return c.json({ error: 'Failed to create user' }, 500);
  }
});

// Login endpoint (uses Supabase client-side auth, this is for validation)
app.post("/make-server-d2949e14/login", async (c) => {
  try {
    const { email, password } = await c.req.json();

    const { data, error } = await supabaseClient.auth.signInWithPassword({
      email,
      password,
    });

    if (error) {
      console.error('Login error:', error);
      return c.json({ error: error.message }, 401);
    }

    // Get user profile from KV store
    const profile = await kv.get(`user:${data.user.id}`);

    return c.json({ 
      success: true,
      user: {
        id: data.user.id,
        email: data.user.email,
        ...profile
      },
      session: {
        access_token: data.session.access_token,
        refresh_token: data.session.refresh_token
      }
    });
  } catch (error) {
    console.error('Login error:', error);
    return c.json({ error: 'Failed to login' }, 500);
  }
});

// Get user profile endpoint
app.get("/make-server-d2949e14/profile", async (c) => {
  try {
    const accessToken = c.req.header('Authorization')?.split(' ')[1];
    
    if (!accessToken) {
      return c.json({ error: 'Unauthorized' }, 401);
    }

    const { data: { user }, error } = await supabaseAdmin.auth.getUser(accessToken);

    if (error || !user) {
      console.error('Auth error while fetching profile:', error);
      return c.json({ error: 'Unauthorized' }, 401);
    }

    // Get user profile from KV store
    const profile = await kv.get(`user:${user.id}`);

    if (!profile) {
      return c.json({ error: 'Profile not found' }, 404);
    }

    return c.json({ 
      success: true,
      profile
    });
  } catch (error) {
    console.error('Profile fetch error:', error);
    return c.json({ error: 'Failed to fetch profile' }, 500);
  }
});

// Update user stats endpoint
app.post("/make-server-d2949e14/update-stats", async (c) => {
  try {
    const accessToken = c.req.header('Authorization')?.split(' ')[1];
    
    if (!accessToken) {
      return c.json({ error: 'Unauthorized' }, 401);
    }

    const { data: { user }, error } = await supabaseAdmin.auth.getUser(accessToken);

    if (error || !user) {
      console.error('Auth error while updating stats:', error);
      return c.json({ error: 'Unauthorized' }, 401);
    }

    const { decision } = await c.req.json();

    // Get current profile
    const profile = await kv.get(`user:${user.id}`);

    if (!profile) {
      return c.json({ error: 'Profile not found' }, 404);
    }

    // Update stats based on decision
    profile.stats.analyzedPrompts++;
    if (decision === 'BLOCK') {
      profile.stats.blockedThreats++;
    } else if (decision === 'ALLOW') {
      profile.stats.allowedPrompts++;
    } else if (decision === 'HESITATE') {
      profile.stats.hesitateCases++;
    }

    // Save updated profile
    await kv.set(`user:${user.id}`, profile);

    // Also store analysis history
    const analysisId = `analysis:${user.id}:${Date.now()}`;
    await kv.set(analysisId, {
      userId: user.id,
      decision,
      timestamp: new Date().toISOString()
    });

    return c.json({ 
      success: true,
      stats: profile.stats
    });
  } catch (error) {
    console.error('Stats update error:', error);
    return c.json({ error: 'Failed to update stats' }, 500);
  }
});

// Admin: Get all users endpoint
app.get("/make-server-d2949e14/admin/users", async (c) => {
  try {
    const accessToken = c.req.header('Authorization')?.split(' ')[1];
    
    if (!accessToken) {
      return c.json({ error: 'Unauthorized' }, 401);
    }

    const { data: { user }, error } = await supabaseAdmin.auth.getUser(accessToken);

    if (error || !user) {
      console.error('Auth error in admin users endpoint:', error);
      return c.json({ error: 'Unauthorized' }, 401);
    }

    // Check if user is admin
    const profile = await kv.get(`user:${user.id}`);
    if (!profile || profile.role !== 'admin') {
      return c.json({ error: 'Forbidden: Admin access required' }, 403);
    }

    // Get all user profiles
    const allUsers = await kv.getByPrefix('user:');

    return c.json({ 
      success: true,
      users: allUsers
    });
  } catch (error) {
    console.error('Admin users fetch error:', error);
    return c.json({ error: 'Failed to fetch users' }, 500);
  }
});

// Admin: Get analytics endpoint
app.get("/make-server-d2949e14/admin/analytics", async (c) => {
  try {
    const accessToken = c.req.header('Authorization')?.split(' ')[1];
    
    if (!accessToken) {
      return c.json({ error: 'Unauthorized' }, 401);
    }

    const { data: { user }, error } = await supabaseAdmin.auth.getUser(accessToken);

    if (error || !user) {
      console.error('Auth error in admin analytics endpoint:', error);
      return c.json({ error: 'Unauthorized' }, 401);
    }

    // Check if user is admin
    const profile = await kv.get(`user:${user.id}`);
    if (!profile || profile.role !== 'admin') {
      return c.json({ error: 'Forbidden: Admin access required' }, 403);
    }

    // Get all users and calculate total stats
    const allUsers = await kv.getByPrefix('user:');
    
    const totalStats = allUsers.reduce((acc, user) => {
      if (user.stats) {
        acc.totalUsers++;
        acc.analyzedPrompts += user.stats.analyzedPrompts || 0;
        acc.blockedThreats += user.stats.blockedThreats || 0;
        acc.allowedPrompts += user.stats.allowedPrompts || 0;
        acc.hesitateCases += user.stats.hesitateCases || 0;
      }
      return acc;
    }, {
      totalUsers: 0,
      analyzedPrompts: 0,
      blockedThreats: 0,
      allowedPrompts: 0,
      hesitateCases: 0
    });

    // Get recent analyses
    const allAnalyses = await kv.getByPrefix('analysis:');
    const recentAnalyses = allAnalyses
      .sort((a, b) => new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime())
      .slice(0, 10);

    return c.json({ 
      success: true,
      analytics: {
        ...totalStats,
        recentAnalyses
      }
    });
  } catch (error) {
    console.error('Admin analytics fetch error:', error);
    return c.json({ error: 'Failed to fetch analytics' }, 500);
  }
});

Deno.serve(app.fetch);
