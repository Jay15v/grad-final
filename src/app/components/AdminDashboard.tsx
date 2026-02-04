import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { motion } from 'motion/react';
import { Shield, Users, Activity, TrendingUp, AlertTriangle, CheckCircle, AlertCircle, BarChart3 } from 'lucide-react';
import { useAuth } from '@/app/context/AuthContext';
import { API_BASE_URL } from '@/app/utils/supabaseClient';
import { Card } from '@/app/components/ui/card';

interface Analytics {
  totalUsers: number;
  analyzedPrompts: number;
  blockedThreats: number;
  allowedPrompts: number;
  hesitateCases: number;
  recentAnalyses: Array<{
    userId: string;
    decision: string;
    timestamp: string;
  }>;
}

interface User {
  id: string;
  email: string;
  name: string;
  role: string;
  stats: {
    analyzedPrompts: number;
    blockedThreats: number;
    allowedPrompts: number;
    hesitateCases: number;
  };
}

export function AdminDashboard() {
  const navigate = useNavigate();
  const { user, accessToken, isLoading } = useAuth();
  const [analytics, setAnalytics] = useState<Analytics | null>(null);
  const [users, setUsers] = useState<User[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!isLoading && (!user || user.role !== 'admin')) {
      navigate('/');
    } else if (user && user.role === 'admin') {
      fetchData();
    }
  }, [user, isLoading, navigate]);

  const fetchData = async () => {
    if (!accessToken) return;

    try {
      setLoading(true);

      // Fetch analytics
      const analyticsRes = await fetch(`${API_BASE_URL}/admin/analytics`, {
        headers: {
          'Authorization': `Bearer ${accessToken}`,
        },
      });

      if (analyticsRes.ok) {
        const analyticsData = await analyticsRes.json();
        setAnalytics(analyticsData.analytics);
      }

      // Fetch users
      const usersRes = await fetch(`${API_BASE_URL}/admin/users`, {
        headers: {
          'Authorization': `Bearer ${accessToken}`,
        },
      });

      if (usersRes.ok) {
        const usersData = await usersRes.json();
        setUsers(usersData.users);
      }
    } catch (error) {
      console.error('Error fetching admin data:', error);
    } finally {
      setLoading(false);
    }
  };

  if (isLoading || loading || !user) {
    return (
      <div className="flex-1 flex items-center justify-center">
        <div className="w-8 h-8 border-2 border-cyan-500/20 border-t-cyan-500 rounded-full animate-spin" />
      </div>
    );
  }

  const threatBlockRate = analytics?.analyzedPrompts 
    ? ((analytics.blockedThreats / analytics.analyzedPrompts) * 100).toFixed(1)
    : '0';

  return (
    <div className="flex-1 px-4 sm:px-6 lg:px-8 py-12">
      <div className="max-w-7xl mx-auto">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6 }}
        >
          {/* Header */}
          <div className="mb-8">
            <div className="flex items-center gap-3 mb-2">
              <div className="w-12 h-12 bg-gradient-to-br from-purple-500 to-blue-600 rounded-lg flex items-center justify-center">
                <Shield className="w-6 h-6 text-white" />
              </div>
              <div>
                <h1 className="text-4xl font-bold text-white">Admin Dashboard</h1>
                <p className="text-purple-400/70">System Analytics & User Management</p>
              </div>
            </div>
          </div>

          {/* Key Metrics Grid */}
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
            {/* Total Users */}
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.1 }}
              className="bg-slate-900/80 backdrop-blur-md border border-purple-500/20 rounded-xl p-6 hover:border-purple-500/40 transition-all"
            >
              <div className="flex items-center justify-between mb-4">
                <div className="w-10 h-10 bg-purple-500/20 rounded-lg flex items-center justify-center">
                  <Users className="w-5 h-5 text-purple-400" />
                </div>
                <TrendingUp className="w-5 h-5 text-green-400" />
              </div>
              <div className="text-3xl font-bold text-white mb-1">{analytics?.totalUsers || 0}</div>
              <div className="text-purple-400/70 text-sm">Total Users</div>
            </motion.div>

            {/* Total Analyzed */}
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.2 }}
              className="bg-slate-900/80 backdrop-blur-md border border-cyan-500/20 rounded-xl p-6 hover:border-cyan-500/40 transition-all"
            >
              <div className="flex items-center justify-between mb-4">
                <div className="w-10 h-10 bg-cyan-500/20 rounded-lg flex items-center justify-center">
                  <Activity className="w-5 h-5 text-cyan-400" />
                </div>
                <BarChart3 className="w-5 h-5 text-cyan-400" />
              </div>
              <div className="text-3xl font-bold text-white mb-1">{analytics?.analyzedPrompts || 0}</div>
              <div className="text-cyan-400/70 text-sm">Prompts Analyzed</div>
            </motion.div>

            {/* Blocked Threats */}
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.3 }}
              className="bg-slate-900/80 backdrop-blur-md border border-red-500/20 rounded-xl p-6 hover:border-red-500/40 transition-all"
            >
              <div className="flex items-center justify-between mb-4">
                <div className="w-10 h-10 bg-red-500/20 rounded-lg flex items-center justify-center">
                  <AlertTriangle className="w-5 h-5 text-red-400" />
                </div>
                <span className="text-red-400 text-sm font-medium">{threatBlockRate}%</span>
              </div>
              <div className="text-3xl font-bold text-white mb-1">{analytics?.blockedThreats || 0}</div>
              <div className="text-red-400/70 text-sm">Threats Blocked</div>
            </motion.div>

            {/* Allowed Prompts */}
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.4 }}
              className="bg-slate-900/80 backdrop-blur-md border border-green-500/20 rounded-xl p-6 hover:border-green-500/40 transition-all"
            >
              <div className="flex items-center justify-between mb-4">
                <div className="w-10 h-10 bg-green-500/20 rounded-lg flex items-center justify-center">
                  <CheckCircle className="w-5 h-5 text-green-400" />
                </div>
              </div>
              <div className="text-3xl font-bold text-white mb-1">{analytics?.allowedPrompts || 0}</div>
              <div className="text-green-400/70 text-sm">Prompts Allowed</div>
            </motion.div>
          </div>

          {/* Defense Layer Performance */}
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
            {/* System Health */}
            <div className="bg-slate-900/80 backdrop-blur-md border border-cyan-500/20 rounded-xl p-6">
              <h3 className="text-xl font-bold text-white mb-6 flex items-center gap-2">
                <Shield className="w-5 h-5 text-cyan-400" />
                Defense System Health
              </h3>
              
              <div className="space-y-4">
                <div>
                  <div className="flex justify-between text-sm mb-2">
                    <span className="text-slate-300">Rule-Based Defense</span>
                    <span className="text-green-400 font-medium">Operational</span>
                  </div>
                  <div className="w-full bg-slate-950/50 rounded-full h-2">
                    <div className="bg-gradient-to-r from-green-500 to-emerald-500 h-2 rounded-full" style={{ width: '98%' }} />
                  </div>
                </div>

                <div>
                  <div className="flex justify-between text-sm mb-2">
                    <span className="text-slate-300">Pattern Knowledge Base</span>
                    <span className="text-green-400 font-medium">Operational</span>
                  </div>
                  <div className="w-full bg-slate-950/50 rounded-full h-2">
                    <div className="bg-gradient-to-r from-green-500 to-emerald-500 h-2 rounded-full" style={{ width: '95%' }} />
                  </div>
                </div>

                <div>
                  <div className="flex justify-between text-sm mb-2">
                    <span className="text-slate-300">Semantic Reasoning</span>
                    <span className="text-green-400 font-medium">Operational</span>
                  </div>
                  <div className="w-full bg-slate-950/50 rounded-full h-2">
                    <div className="bg-gradient-to-r from-green-500 to-emerald-500 h-2 rounded-full" style={{ width: '92%' }} />
                  </div>
                </div>

                <div>
                  <div className="flex justify-between text-sm mb-2">
                    <span className="text-slate-300">Risk Fusion & Calibration</span>
                    <span className="text-green-400 font-medium">Operational</span>
                  </div>
                  <div className="w-full bg-slate-950/50 rounded-full h-2">
                    <div className="bg-gradient-to-r from-green-500 to-emerald-500 h-2 rounded-full" style={{ width: '97%' }} />
                  </div>
                </div>
              </div>
            </div>

            {/* Decision Distribution */}
            <div className="bg-slate-900/80 backdrop-blur-md border border-cyan-500/20 rounded-xl p-6">
              <h3 className="text-xl font-bold text-white mb-6 flex items-center gap-2">
                <BarChart3 className="w-5 h-5 text-cyan-400" />
                Decision Distribution
              </h3>
              
              <div className="space-y-6">
                <div className="flex items-center gap-4">
                  <div className="flex-1">
                    <div className="flex justify-between text-sm mb-2">
                      <span className="text-slate-300">Allowed</span>
                      <span className="text-green-400 font-medium">{analytics?.allowedPrompts || 0}</span>
                    </div>
                    <div className="w-full bg-slate-950/50 rounded-full h-3">
                      <div 
                        className="bg-gradient-to-r from-green-500 to-emerald-500 h-3 rounded-full transition-all" 
                        style={{ 
                          width: analytics?.analyzedPrompts 
                            ? `${(analytics.allowedPrompts / analytics.analyzedPrompts) * 100}%`
                            : '0%'
                        }} 
                      />
                    </div>
                  </div>
                </div>

                <div className="flex items-center gap-4">
                  <div className="flex-1">
                    <div className="flex justify-between text-sm mb-2">
                      <span className="text-slate-300">Blocked</span>
                      <span className="text-red-400 font-medium">{analytics?.blockedThreats || 0}</span>
                    </div>
                    <div className="w-full bg-slate-950/50 rounded-full h-3">
                      <div 
                        className="bg-gradient-to-r from-red-500 to-rose-500 h-3 rounded-full transition-all" 
                        style={{ 
                          width: analytics?.analyzedPrompts 
                            ? `${(analytics.blockedThreats / analytics.analyzedPrompts) * 100}%`
                            : '0%'
                        }} 
                      />
                    </div>
                  </div>
                </div>

                <div className="flex items-center gap-4">
                  <div className="flex-1">
                    <div className="flex justify-between text-sm mb-2">
                      <span className="text-slate-300">Hesitate</span>
                      <span className="text-yellow-400 font-medium">{analytics?.hesitateCases || 0}</span>
                    </div>
                    <div className="w-full bg-slate-950/50 rounded-full h-3">
                      <div 
                        className="bg-gradient-to-r from-yellow-500 to-amber-500 h-3 rounded-full transition-all" 
                        style={{ 
                          width: analytics?.analyzedPrompts 
                            ? `${(analytics.hesitateCases / analytics.analyzedPrompts) * 100}%`
                            : '0%'
                        }} 
                      />
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>

          {/* User Management Table */}
          <div className="bg-slate-900/80 backdrop-blur-md border border-cyan-500/20 rounded-xl p-6">
            <h3 className="text-xl font-bold text-white mb-6 flex items-center gap-2">
              <Users className="w-5 h-5 text-cyan-400" />
              User Management ({users.length} Users)
            </h3>

            <div className="overflow-x-auto">
              <table className="w-full">
                <thead>
                  <tr className="border-b border-cyan-500/10">
                    <th className="text-left py-3 px-4 text-sm font-medium text-cyan-400">Name</th>
                    <th className="text-left py-3 px-4 text-sm font-medium text-cyan-400">Email</th>
                    <th className="text-left py-3 px-4 text-sm font-medium text-cyan-400">Role</th>
                    <th className="text-center py-3 px-4 text-sm font-medium text-cyan-400">Analyzed</th>
                    <th className="text-center py-3 px-4 text-sm font-medium text-cyan-400">Blocked</th>
                    <th className="text-center py-3 px-4 text-sm font-medium text-cyan-400">Allowed</th>
                  </tr>
                </thead>
                <tbody>
                  {users.map((u, index) => (
                    <tr key={u.id} className="border-b border-slate-800/50 hover:bg-slate-800/30 transition-colors">
                      <td className="py-3 px-4 text-sm text-white">{u.name}</td>
                      <td className="py-3 px-4 text-sm text-slate-300">{u.email}</td>
                      <td className="py-3 px-4">
                        <span className={`inline-flex px-2 py-1 rounded text-xs font-medium ${
                          u.role === 'admin' 
                            ? 'bg-purple-500/20 text-purple-300 border border-purple-500/30'
                            : 'bg-cyan-500/20 text-cyan-300 border border-cyan-500/30'
                        }`}>
                          {u.role}
                        </span>
                      </td>
                      <td className="py-3 px-4 text-sm text-center text-slate-300">{u.stats.analyzedPrompts}</td>
                      <td className="py-3 px-4 text-sm text-center text-red-400">{u.stats.blockedThreats}</td>
                      <td className="py-3 px-4 text-sm text-center text-green-400">{u.stats.allowedPrompts}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        </motion.div>
      </div>
    </div>
  );
}
