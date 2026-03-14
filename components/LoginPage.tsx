import React, { useState } from 'react';
import { User, Lock, Building2, ArrowRight, Loader2, AlertCircle, HardHat, KeyRound, Download, Mail, Eye, EyeOff } from 'lucide-react';
import { UserSession } from '../types';
import { loginUser, signupUser, loginCrew, resetPassword } from '../services/supabase';

interface LoginPageProps {
  onLoginSuccess: (session: UserSession) => void;
  installPrompt: any;
  onInstall: () => void;
}

type AuthMode = 'login' | 'signup' | 'forgot-password';

const LoginPage: React.FC<LoginPageProps> = ({ onLoginSuccess, installPrompt, onInstall }) => {
  const [activeTab, setActiveTab] = useState<'admin' | 'crew'>('admin');
  const [authMode, setAuthMode] = useState<AuthMode>('login');
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);
  const [showPassword, setShowPassword] = useState(false);

  const [formData, setFormData] = useState({
    email: '',
    password: '',
    companyName: '',
    crewPin: ''
  });

  const [username, setUsername] = useState('');

  // Password validation
  const [passwordValidation, setPasswordValidation] = useState({
    hasMinLength: false,
    hasNumber: false,
    hasSpecialChar: false
  });

  const handlePasswordChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const pwd = e.target.value;
    setFormData({ ...formData, password: pwd });
    setPasswordValidation({
      hasMinLength: pwd.length >= 8,
      hasNumber: /\d/.test(pwd),
      hasSpecialChar: /[!@#$%^&*(),.?":{}|<>]/.test(pwd)
    });
  };

  const isPasswordValid = passwordValidation.hasMinLength && passwordValidation.hasNumber && passwordValidation.hasSpecialChar;

  const validateEmail = (email: string) => {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setSuccessMessage(null);
    setIsLoading(true);

    try {
      if (activeTab === 'crew') {
        // Crew Login
        if (!username || !formData.crewPin) {
          setError('Please enter company username and crew PIN');
          setIsLoading(false);
          return;
        }
        const session = await loginCrew(username, formData.crewPin);
        if (session) {
          onLoginSuccess(session);
        } else {
          setError('Invalid company username or PIN');
        }
      } else {
        // Admin Login/Signup/Forgot Password
        if (authMode === 'forgot-password') {
          if (!validateEmail(formData.email)) {
            setError('Please enter a valid email address');
            setIsLoading(false);
            return;
          }
          await resetPassword(formData.email);
          setSuccessMessage('Password reset email sent! Check your inbox.');
          setAuthMode('login');
        } else if (authMode === 'signup') {
          if (!validateEmail(formData.email)) {
            setError('Please enter a valid email address');
            setIsLoading(false);
            return;
          }
          if (!isPasswordValid) {
            setError('Password does not meet requirements');
            setIsLoading(false);
            return;
          }
          if (!formData.companyName.trim()) {
            setError('Company name is required');
            setIsLoading(false);
            return;
          }
          const session = await signupUser(formData.email, formData.password, formData.companyName, formData.email);
          if (session) {
            onLoginSuccess(session);
          } else {
            // null means email confirmation is required (not an error)
            setSuccessMessage('Account created! Please check your email to verify your account.');
          }
        } else {
          // Login
          if (!formData.email || !formData.password) {
            setError('Please enter email and password');
            setIsLoading(false);
            return;
          }
          const session = await loginUser(formData.email, formData.password);
          if (session) {
            onLoginSuccess(session);
          } else {
            setError('Invalid credentials');
          }
        }
      }
    } catch (err: any) {
      console.error('Auth error:', err);
      setError(err.message || 'An unexpected error occurred');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center p-4 bg-slate-100">
      <div className="bg-white w-full max-w-md rounded-2xl shadow-xl overflow-hidden animate-in fade-in zoom-in duration-300 relative">

        {/* PWA Install Banner */}
        {installPrompt && (
          <button
            onClick={onInstall}
            className="w-full bg-emerald-600 text-white py-2 px-4 text-xs font-bold uppercase tracking-widest flex items-center justify-center gap-2 hover:bg-emerald-700 transition-colors"
          >
            <Download className="w-4 h-4" /> Install Desktop/Mobile App
          </button>
        )}

        {/* Header */}
        <div className="bg-slate-900 p-10 text-center relative overflow-hidden">
          <div className="relative z-10 flex flex-col items-center justify-center select-none">
            {/* RFE Logo Block */}
            <div className="flex items-center gap-2 mb-2">
                 <div className="bg-brand text-white px-2 py-0.5 -skew-x-12 transform origin-bottom-left shadow-sm flex items-center justify-center">
                    <span className="skew-x-12 font-black text-3xl tracking-tighter">RFE</span>
                 </div>
                 <span className="text-3xl font-black italic tracking-tighter text-white leading-none">RFE</span>
            </div>
            {/* Subtext */}
            <span className="text-[0.6rem] font-bold tracking-[0.2em] text-brand-yellow bg-black px-2 py-0.5 leading-none">FOAM EQUIPMENT</span>

            <p className="text-slate-400 text-xs mt-4 uppercase tracking-widest font-bold">Professional Estimation Suite</p>
          </div>
          <div className="absolute inset-0 opacity-20 bg-[radial-gradient(ellipse_at_top,_var(--tw-gradient-stops))] from-brand via-slate-900 to-slate-900"></div>
        </div>

        {/* Tab Switcher */}
        <div className="flex border-b border-slate-100">
            <button
                onClick={() => { setActiveTab('admin'); setAuthMode('login'); setError(null); setSuccessMessage(null); }}
                className={`flex-1 py-4 text-sm font-bold uppercase tracking-wider transition-colors ${activeTab === 'admin' ? 'text-brand border-b-2 border-brand' : 'text-slate-400 hover:text-slate-600'}`}
            >
                Admin Access
            </button>
            <button
                onClick={() => { setActiveTab('crew'); setAuthMode('login'); setError(null); setSuccessMessage(null); }}
                className={`flex-1 py-4 text-sm font-bold uppercase tracking-wider transition-colors ${activeTab === 'crew' ? 'text-brand border-b-2 border-brand' : 'text-slate-400 hover:text-slate-600'}`}
            >
                Crew Login
            </button>
        </div>

        {/* Form */}
        <div className="p-8">
          <h2 className="text-xl font-bold text-slate-800 mb-6 text-center">
             {activeTab === 'crew' ? 'Job Execution Portal' : (authMode === 'signup' ? 'Create Company Account' : authMode === 'forgot-password' ? 'Reset Password' : 'Welcome Back')}
          </h2>

          {error && (
            <div className="mb-6 p-3 bg-red-50 text-red-600 text-sm rounded-lg flex items-center gap-2 border border-red-100">
              <AlertCircle className="w-4 h-4 shrink-0" />
              {error}
            </div>
          )}

          {successMessage && (
            <div className="mb-6 p-3 bg-green-50 text-green-600 text-sm rounded-lg flex items-center gap-2 border border-green-100">
              <AlertCircle className="w-4 h-4 shrink-0" />
              {successMessage}
            </div>
          )}

          <form onSubmit={handleSubmit} className="space-y-4">

            {activeTab === 'admin' && authMode === 'signup' && (
              <div>
                <label className="block text-xs font-bold text-slate-500 uppercase mb-1 ml-1">Company Name</label>
                <div className="relative">
                  <Building2 className="absolute left-3 top-3 w-5 h-5 text-slate-400" />
                  <input
                    type="text"
                    required
                    className="w-full pl-10 pr-4 py-2.5 bg-slate-50 border border-slate-200 rounded-xl focus:ring-2 focus:ring-brand outline-none transition-all"
                    placeholder="Acme Insulation"
                    value={formData.companyName}
                    onChange={e => setFormData({...formData, companyName: e.target.value})}
                  />
                </div>
              </div>
            )}

            {activeTab === 'admin' ? (
              <>
                <div>
                  <label className="block text-xs font-bold text-slate-500 uppercase mb-1 ml-1">Email Address</label>
                  <div className="relative">
                    <Mail className="absolute left-3 top-3 w-5 h-5 text-slate-400" />
                    <input
                      type="email"
                      required
                      className="w-full pl-10 pr-4 py-2.5 bg-slate-50 border border-slate-200 rounded-xl focus:ring-2 focus:ring-brand outline-none transition-all"
                      placeholder="you@company.com"
                      value={formData.email}
                      onChange={e => setFormData({...formData, email: e.target.value})}
                    />
                  </div>
                </div>

                {authMode !== 'forgot-password' && (
                  <div>
                    <label className="block text-xs font-bold text-slate-500 uppercase mb-1 ml-1">Password</label>
                    <div className="relative">
                      <Lock className="absolute left-3 top-3 w-5 h-5 text-slate-400" />
                      <input
                        type={showPassword ? 'text' : 'password'}
                        required
                        className="w-full pl-10 pr-12 py-2.5 bg-slate-50 border border-slate-200 rounded-xl focus:ring-2 focus:ring-brand outline-none transition-all"
                        placeholder="••••••••"
                        value={formData.password}
                        onChange={handlePasswordChange}
                      />
                      <button
                        type="button"
                        onClick={() => setShowPassword(!showPassword)}
                        className="absolute right-3 top-3 text-slate-400 hover:text-slate-600"
                      >
                        {showPassword ? <EyeOff className="w-5 h-5" /> : <Eye className="w-5 h-5" />}
                      </button>
                    </div>

                    {authMode === 'signup' && (
                      <div className="mt-2 space-y-1">
                        <p className="text-xs font-bold text-slate-500 uppercase mb-1">Password Requirements:</p>
                        <div className={`text-xs flex items-center gap-2 ${passwordValidation.hasMinLength ? 'text-green-600' : 'text-slate-400'}`}>
                          <span className={`w-1.5 h-1.5 rounded-full ${passwordValidation.hasMinLength ? 'bg-green-600' : 'bg-slate-300'}`}></span>
                          At least 8 characters
                        </div>
                        <div className={`text-xs flex items-center gap-2 ${passwordValidation.hasNumber ? 'text-green-600' : 'text-slate-400'}`}>
                          <span className={`w-1.5 h-1.5 rounded-full ${passwordValidation.hasNumber ? 'bg-green-600' : 'bg-slate-300'}`}></span>
                          Contains a number
                        </div>
                        <div className={`text-xs flex items-center gap-2 ${passwordValidation.hasSpecialChar ? 'text-green-600' : 'text-slate-400'}`}>
                          <span className={`w-1.5 h-1.5 rounded-full ${passwordValidation.hasSpecialChar ? 'bg-green-600' : 'bg-slate-300'}`}></span>
                          Contains a special character (!@#$%^&*)
                        </div>
                      </div>
                    )}
                  </div>
                )}
              </>
            ) : (
              <>
                <div>
                  <label className="block text-xs font-bold text-slate-500 uppercase mb-1 ml-1">Company Username</label>
                  <div className="relative">
                    <User className="absolute left-3 top-3 w-5 h-5 text-slate-400" />
                    <input
                      type="text"
                      required
                      className="w-full pl-10 pr-4 py-2.5 bg-slate-50 border border-slate-200 rounded-xl focus:ring-2 focus:ring-brand outline-none transition-all"
                      placeholder="company123"
                      value={username}
                      onChange={e => setUsername(e.target.value)}
                    />
                  </div>
                </div>

                <div>
                  <label className="block text-xs font-bold text-slate-500 uppercase mb-1 ml-1">Crew Access PIN</label>
                  <div className="relative">
                    <KeyRound className="absolute left-3 top-3 w-5 h-5 text-slate-400" />
                    <input
                      type="password"
                      required
                      className="w-full pl-10 pr-4 py-2.5 bg-slate-50 border border-slate-200 rounded-xl focus:ring-2 focus:ring-brand outline-none transition-all"
                      placeholder="Enter PIN"
                      value={formData.crewPin}
                      onChange={e => setFormData({...formData, crewPin: e.target.value})}
                    />
                  </div>
                </div>
              </>
            )}

            <button
              type="submit"
              disabled={isLoading || (authMode === 'signup' && !isPasswordValid)}
              className="w-full bg-brand hover:bg-brand-hover text-white font-bold py-3 rounded-xl shadow-lg shadow-red-200 transition-all flex items-center justify-center gap-2 mt-4 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {isLoading ? (
                <>
                  <Loader2 className="w-5 h-5 animate-spin" />
                  {authMode === 'forgot-password' ? 'Sending...' : (authMode === 'signup' ? 'Creating Account...' : 'Authenticating...')}
                </>
              ) : (
                <>
                  {activeTab === 'crew' ? 'Access Jobs' : (authMode === 'signup' ? 'Create Account' : authMode === 'forgot-password' ? 'Send Reset Email' : 'Login')}
                  <ArrowRight className="w-5 h-5" />
                </>
              )}
            </button>

          </form>

          {activeTab === 'admin' && authMode === 'login' && (
            <div className="mt-6 space-y-3 text-center">
              <button
                type="button"
                onClick={() => { setAuthMode('forgot-password'); setError(null); setSuccessMessage(null); }}
                className="text-sm text-brand hover:text-brand-hover font-medium transition-colors block w-full"
              >
                Forgot your password?
              </button>
              <div className="text-slate-300">|</div>
              <button
                type="button"
                onClick={() => { setAuthMode('signup'); setError(null); setSuccessMessage(null); }}
                className="text-sm text-slate-500 hover:text-brand font-medium transition-colors block w-full"
              >
                Don't have an account? Sign up
              </button>
            </div>
          )}

          {activeTab === 'admin' && authMode === 'signup' && (
            <div className="mt-6 text-center">
              <button
                type="button"
                onClick={() => { setAuthMode('login'); setError(null); setSuccessMessage(null); }}
                className="text-sm text-slate-500 hover:text-brand font-medium transition-colors"
              >
                Already have an account? Login
              </button>
            </div>
          )}

          {activeTab === 'admin' && authMode === 'forgot-password' && (
            <div className="mt-6 text-center">
              <button
                type="button"
                onClick={() => { setAuthMode('login'); setError(null); setSuccessMessage(null); }}
                className="text-sm text-slate-500 hover:text-brand font-medium transition-colors"
              >
                Back to Login
              </button>
            </div>
          )}

          {activeTab === 'crew' && (
             <div className="mt-6 text-center text-xs text-slate-400">
                Contact your administrator if you don't have the Company ID or Crew PIN.
             </div>
          )}

        </div>
      </div>
    </div>
  );
};

export default LoginPage;
