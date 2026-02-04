import { useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { motion } from 'motion/react';
import { Shield, User, Mail, Calendar, Shield as ShieldCheck } from 'lucide-react';
import { Button } from '@/app/components/ui/button';
import { useAuth } from '@/app/context/AuthContext';

export function ProfilePage() {
  const navigate = useNavigate();
  const { user, logout, isLoading } = useAuth();

  useEffect(() => {
    if (!isLoading && !user) {
      navigate('/login');
    }
  }, [user, isLoading, navigate]);

  const handleLogout = async () => {
    try {
      await logout();
      navigate('/login');
    } catch (error) {
      console.error('Logout error:', error);
    }
  };

  if (isLoading || !user) {
    return (
      <div className="flex-1 flex items-center justify-center">
        <div className="w-8 h-8 border-2 border-cyan-500/20 border-t-cyan-500 rounded-full animate-spin" />
      </div>
    );
  }

  const formatDate = (dateString: string) => {
    const date = new Date(dateString);
    return date.toLocaleDateString('en-US', { month: 'long', year: 'numeric' });
  };

  return (
    <div className="flex-1 px-4 sm:px-6 lg:px-8 py-12">
      <div className="max-w-4xl mx-auto">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6 }}
        >
          {/* Page Header */}
          <div className="mb-8">
            <h1 className="text-4xl font-bold text-white mb-2">User Profile</h1>
            <p className="text-cyan-400/70">Manage your AegisMind account</p>
          </div>

          {/* Profile Card */}
          <div className="bg-slate-900/80 backdrop-blur-md border border-cyan-500/20 rounded-2xl shadow-2xl shadow-cyan-500/10 overflow-hidden mb-6">
            {/* Header Section */}
            <div className="bg-gradient-to-br from-cyan-500/10 to-blue-600/10 border-b border-cyan-500/20 p-8">
              <div className="flex flex-col sm:flex-row items-center gap-6">
                {/* Avatar */}
                <div className="relative">
                  <div className="absolute inset-0 bg-cyan-500/20 blur-xl rounded-full" />
                  <div className="relative w-24 h-24 bg-gradient-to-br from-cyan-500 to-blue-600 rounded-full flex items-center justify-center shadow-lg shadow-cyan-500/30">
                    <User className="w-12 h-12 text-white" strokeWidth={2} />
                  </div>
                </div>

                {/* User Info */}
                <div className="flex-1 text-center sm:text-left">
                  <h2 className="text-2xl font-bold text-white mb-1">{user.name}</h2>
                  <div className="flex flex-col sm:flex-row items-center gap-4 text-cyan-400/70 text-sm">
                    <div className="flex items-center gap-2">
                      <Mail className="w-4 h-4" />
                      <span>{user.email}</span>
                    </div>
                    <div className="flex items-center gap-2">
                      <Calendar className="w-4 h-4" />
                      <span>Joined {formatDate(user.joinDate)}</span>
                    </div>
                  </div>
                  {user.role === 'admin' && (
                    <div className="mt-2">
                      <span className="inline-flex items-center gap-1 px-3 py-1 bg-purple-500/20 border border-purple-500/30 rounded-full text-purple-300 text-xs font-medium">
                        <Shield className="w-3 h-3" />
                        Admin
                      </span>
                    </div>
                  )}
                </div>

                {/* Edit Button */}
                <Button
                  variant="ghost"
                  onClick={handleLogout}
                  className="text-red-400 hover:text-red-300 hover:bg-red-500/10 border border-red-500/20 hover:border-red-500/40 transition-all"
                >
                  Logout
                </Button>
              </div>
            </div>

            {/* Stats Section */}
            <div className="p-8">
              <h3 className="text-xl font-bold text-white mb-6 flex items-center gap-2">
                <ShieldCheck className="w-6 h-6 text-cyan-400" />
                Defense Statistics
              </h3>
              
              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
                {/* Total Analyzed */}
                <div className="bg-slate-950/50 border border-cyan-500/10 rounded-xl p-5 hover:border-cyan-500/30 transition-colors">
                  <div className="text-cyan-400/70 text-sm mb-1">Total Analyzed</div>
                  <div className="text-3xl font-bold text-white">{user.stats.analyzedPrompts}</div>
                </div>

                {/* Blocked Threats */}
                <div className="bg-slate-950/50 border border-red-500/10 rounded-xl p-5 hover:border-red-500/30 transition-colors">
                  <div className="text-red-400/70 text-sm mb-1">Blocked Threats</div>
                  <div className="text-3xl font-bold text-white">{user.stats.blockedThreats}</div>
                </div>

                {/* Allowed Prompts */}
                <div className="bg-slate-950/50 border border-green-500/10 rounded-xl p-5 hover:border-green-500/30 transition-colors">
                  <div className="text-green-400/70 text-sm mb-1">Allowed Prompts</div>
                  <div className="text-3xl font-bold text-white">{user.stats.allowedPrompts}</div>
                </div>

                {/* Hesitate Cases */}
                <div className="bg-slate-950/50 border border-yellow-500/10 rounded-xl p-5 hover:border-yellow-500/30 transition-colors">
                  <div className="text-yellow-400/70 text-sm mb-1">Hesitate Cases</div>
                  <div className="text-3xl font-bold text-white">{user.stats.hesitateCases}</div>
                </div>
              </div>
            </div>
          </div>

          {/* Admin Dashboard Link */}
          {user.role === 'admin' && (
            <div className="bg-slate-900/80 backdrop-blur-md border border-purple-500/20 rounded-2xl shadow-2xl shadow-purple-500/10 p-6 mb-6">
              <div className="flex items-center justify-between">
                <div>
                  <h3 className="text-xl font-bold text-white mb-1">Admin Dashboard</h3>
                  <p className="text-purple-400/70 text-sm">View system analytics and user management</p>
                </div>
                <Button
                  onClick={() => navigate('/admin/dashboard')}
                  className="bg-gradient-to-r from-purple-500 to-blue-600 hover:from-purple-400 hover:to-blue-500 text-white shadow-lg shadow-purple-500/20"
                >
                  Go to Dashboard
                </Button>
              </div>
            </div>
          )}

          {/* Account Actions */}
          <div className="bg-slate-900/80 backdrop-blur-md border border-cyan-500/20 rounded-2xl shadow-2xl shadow-cyan-500/10 p-8">
            <h3 className="text-xl font-bold text-white mb-6">Account Settings</h3>
            
            <div className="space-y-4">
              <Button
                variant="ghost"
                className="w-full justify-start text-cyan-400 hover:text-cyan-300 hover:bg-cyan-500/10 border border-cyan-500/20 hover:border-cyan-500/40 transition-all h-12"
              >
                Change Password
              </Button>
              
              <Button
                variant="ghost"
                className="w-full justify-start text-cyan-400 hover:text-cyan-300 hover:bg-cyan-500/10 border border-cyan-500/20 hover:border-cyan-500/40 transition-all h-12"
              >
                Notification Preferences
              </Button>
              
              <Button
                variant="ghost"
                className="w-full justify-start text-cyan-400 hover:text-cyan-300 hover:bg-cyan-500/10 border border-cyan-500/20 hover:border-cyan-500/40 transition-all h-12"
              >
                Export Analysis History
              </Button>
              
              <Button
                variant="ghost"
                className="w-full justify-start text-red-400 hover:text-red-300 hover:bg-red-500/10 border border-red-500/20 hover:border-red-500/40 transition-all h-12"
              >
                Delete Account
              </Button>
            </div>
          </div>
        </motion.div>
      </div>
    </div>
  );
}