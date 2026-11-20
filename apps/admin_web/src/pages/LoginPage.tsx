import React, { useState } from 'react';
import { Truck, ShieldAlert, Languages, Lock, Mail, LogOut, ArrowRight } from 'lucide-react';
import { useAuth } from '../contexts/AuthContext';
import { useLanguage } from '../i18n/LanguageContext';
import { RoleBadge } from '../components/StatusBadge';

export function LoginPage() {
  const { user, profile, signIn, signOut } = useAuth();
  const { t, toggleLocale } = useLanguage();

  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);

  const isSignedInNonAdmin = Boolean(user && (!profile || profile.role !== 'admin' || !profile.is_active));

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setErrorMsg(null);
    setSubmitting(true);
    const { error } = await signIn(email, password);
    if (error) {
      setErrorMsg(t.auth.invalidCredentials);
    }
    setSubmitting(false);
  };

  return (
    <div className="relative flex min-h-screen flex-col items-center justify-center overflow-hidden bg-[#0F172A] px-4 py-10">
      {/* Subtle Background Glow */}
      <div className="pointer-events-none absolute -top-40 start-1/4 h-96 w-96 rounded-full bg-amber-500/15 blur-3xl" />
      <div className="pointer-events-none absolute -bottom-40 end-1/4 h-96 w-96 rounded-full bg-emerald-500/10 blur-3xl" />

      {/* Top Language Toggle */}
      <div className="absolute top-5 end-5 z-10">
        <button
          type="button"
          onClick={toggleLocale}
          className="flex items-center gap-2 rounded-xl border border-slate-700 bg-slate-800/80 px-3.5 py-2 text-xs font-bold text-slate-200 transition hover:border-amber-500/60 hover:text-white"
        >
          <Languages className="h-4 w-4 text-amber-400" />
          <span>{t.common.switchLang}</span>
        </button>
      </div>

      {/* Main Card */}
      <div className="relative z-10 w-full max-w-md rounded-3xl border border-slate-800 bg-white p-7 shadow-2xl sm:p-9">
        {/* Brand Emblem */}
        <div className="flex flex-col items-center text-center">
          <div className="flex h-16 w-16 items-center justify-center rounded-2xl bg-amber-500 text-slate-950 shadow-lg shadow-amber-500/25">
            <Truck className="h-8 w-8 stroke-[2.25]" />
          </div>
          <h1 className="mt-4 text-2xl font-extrabold tracking-tight text-slate-900">
            {t.brand.name}
          </h1>
          <p className="mt-1 text-sm font-medium text-slate-500">{t.brand.subtitle}</p>
        </div>

        {isSignedInNonAdmin ? (
          /* Unauthorized Non-Admin Screen */
          <div className="mt-7 space-y-5">
            <div className="rounded-2xl border border-red-200 bg-red-50 p-4 text-center">
              <div className="mx-auto flex h-12 w-12 items-center justify-center rounded-full bg-red-100 text-red-600">
                <ShieldAlert className="h-6 w-6" />
              </div>
              <h2 className="mt-3 text-lg font-bold text-red-900">
                {t.auth.unauthorizedTitle}
              </h2>
              <p className="mt-1.5 text-sm leading-relaxed text-red-700">
                {t.auth.unauthorizedDesc}
              </p>
            </div>

            <div className="space-y-2.5 rounded-2xl border border-slate-200 bg-slate-50 p-4 text-sm">
              <div className="flex items-center justify-between gap-2">
                <span className="text-slate-500">{t.auth.signedInAs}</span>
                <span className="font-semibold text-slate-900 truncate">{user?.email}</span>
              </div>
              <div className="flex items-center justify-between gap-2">
                <span className="text-slate-500">{t.auth.currentRole}</span>
                {profile ? (
                  <RoleBadge role={profile.role} />
                ) : (
                  <span className="font-semibold text-slate-500">—</span>
                )}
              </div>
              <div className="flex items-center justify-between gap-2">
                <span className="text-slate-500">{t.auth.accountStatus}</span>
                <span
                  className={`font-semibold ${
                    profile?.is_active ? 'text-emerald-600' : 'text-red-600'
                  }`}
                >
                  {profile?.is_active ? t.common.active : t.common.inactive}
                </span>
              </div>
            </div>

            <button
              type="button"
              onClick={() => void signOut()}
              className="flex w-full items-center justify-center gap-2 rounded-xl bg-slate-900 px-4 py-3 text-sm font-bold text-white transition hover:bg-slate-800"
            >
              <LogOut className="h-4 w-4" />
              <span>{t.common.signOut}</span>
            </button>
          </div>
        ) : (
          /* Standard Admin Login Form */
          <form onSubmit={handleSubmit} className="mt-7 space-y-4">
            <div className="text-center">
              <h2 className="text-lg font-bold text-slate-900">{t.auth.title}</h2>
              <p className="mt-1 text-xs text-slate-500">{t.auth.subtitle}</p>
            </div>

            {errorMsg && (
              <div className="rounded-xl border border-red-200 bg-red-50 px-3.5 py-2.5 text-sm font-medium text-red-700">
                {errorMsg}
              </div>
            )}

            <div>
              <label className="mb-1.5 block text-xs font-bold text-slate-700">
                {t.auth.email}
              </label>
              <div className="relative">
                <Mail className="pointer-events-none absolute top-1/2 start-3.5 h-4 w-4 -translate-y-1/2 text-slate-400" />
                <input
                  type="email"
                  required
                  autoComplete="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder={t.auth.emailPlaceholder}
                  className="w-full rounded-xl border border-slate-300 bg-slate-50/50 py-2.5 ps-10 pe-3.5 text-sm text-slate-900 transition focus:border-amber-500 focus:bg-white focus:outline-none focus:ring-2 focus:ring-amber-500/20"
                  dir="ltr"
                />
              </div>
            </div>

            <div>
              <label className="mb-1.5 block text-xs font-bold text-slate-700">
                {t.auth.password}
              </label>
              <div className="relative">
                <Lock className="pointer-events-none absolute top-1/2 start-3.5 h-4 w-4 -translate-y-1/2 text-slate-400" />
                <input
                  type="password"
                  required
                  autoComplete="current-password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder={t.auth.passwordPlaceholder}
                  className="w-full rounded-xl border border-slate-300 bg-slate-50/50 py-2.5 ps-10 pe-3.5 text-sm text-slate-900 transition focus:border-amber-500 focus:bg-white focus:outline-none focus:ring-2 focus:ring-amber-500/20"
                  dir="ltr"
                />
              </div>
            </div>

            <button
              type="submit"
              disabled={submitting}
              className="mt-2 flex w-full items-center justify-center gap-2 rounded-xl bg-amber-500 px-4 py-3 text-sm font-extrabold text-slate-950 shadow-md shadow-amber-500/20 transition hover:bg-amber-400 disabled:opacity-60"
            >
              <span>{submitting ? t.auth.signingIn : t.auth.signIn}</span>
              {!submitting && <ArrowRight className="h-4 w-4 rtl:rotate-180" />}
            </button>

            <p className="pt-2 text-center text-[11px] font-medium text-slate-400">
              {t.auth.securePortal}
            </p>
          </form>
        )}
      </div>
    </div>
  );
}
