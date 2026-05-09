import { create } from 'zustand';
import type { AdminUser } from '../types';

interface AuthState {
  token: string | null;
  admin: AdminUser | null;
  isAuthenticated: boolean;
  login: (token: string, admin: AdminUser) => void;
  logout: () => void;
}

const TOKEN_KEY = 'etcride_admin_token';
const USER_KEY  = 'etcride_admin_user';

const storedToken = localStorage.getItem(TOKEN_KEY);
const storedUser  = (() => {
  try { return JSON.parse(localStorage.getItem(USER_KEY) ?? 'null'); }
  catch { return null; }
})();

export const useAuthStore = create<AuthState>(set => ({
  token:           storedToken,
  admin:           storedUser,
  isAuthenticated: !!storedToken,

  login: (token, admin) => {
    localStorage.setItem(TOKEN_KEY, token);
    localStorage.setItem(USER_KEY, JSON.stringify(admin));
    set({ token, admin, isAuthenticated: true });
  },

  logout: () => {
    localStorage.removeItem(TOKEN_KEY);
    localStorage.removeItem(USER_KEY);
    set({ token: null, admin: null, isAuthenticated: false });
  },
}));
