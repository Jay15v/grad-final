import { createContext, useContext, useState, useEffect, ReactNode } from 'react';
import { supabase, API_BASE_URL } from "@/supabase/supabaseClient";

interface User {
  id: string;
  email: string;
  name: string;
  role: 'user' | 'admin';
  joinDate?: string;
  stats?: {
    analyzedPrompts: number;
    blockedThreats: number;
    allowedPrompts: number;
    hesitateCases: number;
  };
}

interface AuthContextType {
  user: User | null;
  accessToken: string | null;
  isLoading: boolean;
  login: (email: string, password: string) => Promise<void>;
  signup: (email: string, password: string, name: string) => Promise<void>;
  logout: () => Promise<void>;
  refreshProfile: () => Promise<void>;
  updateStats: (decision: 'ALLOW' | 'BLOCK' | 'HESITATE') => Promise<void>;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [accessToken, setAccessToken] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  /* -------------------- SESSION CHECK -------------------- */
  useEffect(() => {
    checkSession();
  }, []);

  const checkSession = async () => {
    try {
      const { data } = await supabase.auth.getSession();

      if (data.session?.access_token) {
        setAccessToken(data.session.access_token);
        await fetchProfile(data.session.access_token);
      }
    } catch (err) {
      console.error('Session check error:', err);
    } finally {
      setIsLoading(false);
    }
  };

  /* -------------------- PROFILE -------------------- */
  const fetchProfile = async (token: string) => {
    try {
      const response = await fetch(`${API_BASE_URL}/profile`, {
        headers: {
          Authorization: `Bearer ${token}`,
        },
      });

      if (!response.ok) {
        throw new Error('Failed to fetch profile');
      }

      const data = await response.json();
      setUser(data.profile);
    } catch (err) {
      console.error('Profile fetch error:', err);
    }
  };

  /* -------------------- LOGIN -------------------- */
  const login = async (email: string, password: string) => {
    const { data, error } = await supabase.auth.signInWithPassword({
      email,
      password,
    });

    if (error) throw error;

    if (data.session) {
      setAccessToken(data.session.access_token);
      await fetchProfile(data.session.access_token);
    }
  };

  /* -------------------- SIGNUP -------------------- */
  const signup = async (email: string, password: string, name: string) => {
    const { data, error } = await supabase.auth.signUp({
      email,
      password,
      options: {
        data: { name },
      },
    });

    if (error) throw error;

    if (data.session) {
      setAccessToken(data.session.access_token);
      await fetchProfile(data.session.access_token);
    }
  };

  /* -------------------- LOGOUT -------------------- */
  const logout = async () => {
    await supabase.auth.signOut();
    setUser(null);
    setAccessToken(null);
  };

  /* -------------------- REFRESH PROFILE -------------------- */
  const refreshProfile = async () => {
    if (accessToken) {
      await fetchProfile(accessToken);
    }
  };

  /* -------------------- UPDATE STATS -------------------- */
  const updateStats = async (decision: 'ALLOW' | 'BLOCK' | 'HESITATE') => {
    if (!accessToken) return;

    try {
      const response = await fetch(`${API_BASE_URL}/update-stats`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${accessToken}`,
        },
        body: JSON.stringify({ decision }),
      });

      if (response.ok) {
        await refreshProfile();
      }
    } catch (err) {
      console.error('Stats update error:', err);
    }
  };

  return (
    <AuthContext.Provider
      value={{
        user,
        accessToken,
        isLoading,
        login,
        signup,
        logout,
        refreshProfile,
        updateStats,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
}
