import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Eye, EyeOff, Layers, Lock, User } from 'lucide-react';
import { useMutation } from '@tanstack/react-query';
import { authApi } from '../../api';
import { useAuthStore } from '../../store/authStore';
import { useToast } from '../../components/ui/Toast';

export function LoginPage() {
  const navigate = useNavigate();
  const { login } = useAuthStore();
  const { toast } = useToast();

  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPass, setShowPass] = useState(false);

  const mutation = useMutation({
    mutationFn: () => authApi.login({ email, password }),
    onSuccess: ({ token, ...admin }) => {
      login(token, admin);
      navigate('/', { replace: true });
    },
    onError: (err: Error) => {
      toast(err.message || 'Login failed. Check your credentials.', 'error');
    },
  });

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!email.trim() || !password.trim()) {
      toast('Please enter email and password.', 'error');
      return;
    }
    mutation.mutate();
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-900 via-slate-800 to-brand-900 flex items-center justify-center p-4">
      <div className="w-full max-w-sm">
        {/* Logo */}
        <div className="flex justify-center mb-8">
          <div className="flex h-16 w-16 items-center justify-center rounded-2xl bg-brand-500 shadow-xl shadow-brand-500/30">
            <Layers size={30} className="text-white" />
          </div>
        </div>

        <div className="rounded-2xl bg-white/10 backdrop-blur-sm border border-white/20 p-8 shadow-2xl">
          <h1 className="text-2xl font-bold text-white text-center mb-1">EtcRide Admin</h1>
          <p className="text-sm text-slate-400 text-center mb-8">Sign in to manage your platform</p>

          <form onSubmit={handleSubmit} className="space-y-5">
            {/* Email */}
            <div className="relative">
              <User size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-400 z-10" />
              <input
                type="email"
                placeholder="Email address"
                value={email}
                onChange={e => setEmail(e.target.value)}
                className="w-full rounded-xl bg-white/10 border border-white/20 pl-10 pr-4 py-3 text-sm text-white placeholder:text-slate-500 focus:outline-none focus:ring-2 focus:ring-brand-500 focus:border-transparent"
                autoComplete="email"
                autoFocus
              />
            </div>

            {/* Password */}
            <div className="relative">
              <Lock size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-400 z-10" />
              <input
                type={showPass ? 'text' : 'password'}
                placeholder="Password"
                value={password}
                onChange={e => setPassword(e.target.value)}
                className="w-full rounded-xl bg-white/10 border border-white/20 pl-10 pr-11 py-3 text-sm text-white placeholder:text-slate-500 focus:outline-none focus:ring-2 focus:ring-brand-500 focus:border-transparent"
                autoComplete="current-password"
              />
              <button
                type="button"
                onClick={() => setShowPass(s => !s)}
                className="absolute right-3.5 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-300"
              >
                {showPass ? <EyeOff size={16} /> : <Eye size={16} />}
              </button>
            </div>

            <button
              type="submit"
              disabled={mutation.isPending}
              className="w-full rounded-xl bg-brand-600 hover:bg-brand-500 text-white text-sm font-semibold py-3 transition-colors disabled:opacity-60 disabled:cursor-not-allowed"
            >
              {mutation.isPending ? 'Signing in…' : 'Sign In'}
            </button>
          </form>
        </div>

        <p className="text-center text-xs text-slate-600 mt-6">
          EtcRide © {new Date().getFullYear()} — Admin Panel
        </p>
      </div>
    </div>
  );
}
