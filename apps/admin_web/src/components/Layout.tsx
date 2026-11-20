import React, { useState } from 'react';
import {
  LayoutDashboard,
  ShieldCheck,
  Navigation,
  MessageSquareWarning,
  Users,
  Truck,
  Languages,
  LogOut,
  Menu,
  X,
  Radio,
} from 'lucide-react';
import { useLanguage } from '../i18n/LanguageContext';
import { useAuth } from '../contexts/AuthContext';

export type AdminRoute =
  | 'overview'
  | 'drivers'
  | 'trips'
  | 'complaints'
  | 'users'
  | 'winchTypes';

export interface NavBadges {
  pendingDrivers?: number;
  activeTrips?: number;
  openComplaints?: number;
}

interface LayoutProps {
  activeRoute: AdminRoute;
  onNavigate: (route: AdminRoute) => void;
  badges?: NavBadges;
  children: React.ReactNode;
}

export function Layout({ activeRoute, onNavigate, badges, children }: LayoutProps) {
  const { t, toggleLocale } = useLanguage();
  const { profile, user, signOut } = useAuth();
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);

  const navItems: Array<{
    id: AdminRoute;
    label: string;
    icon: React.ComponentType<{ className?: string }>;
    badge?: number;
    badgeTone?: 'amber' | 'red' | 'emerald';
  }> = [
    { id: 'overview', label: t.nav.overview, icon: LayoutDashboard },
    {
      id: 'drivers',
      label: t.nav.drivers,
      icon: ShieldCheck,
      badge: badges?.pendingDrivers,
      badgeTone: 'amber',
    },
    {
      id: 'trips',
      label: t.nav.trips,
      icon: Navigation,
      badge: badges?.activeTrips,
      badgeTone: 'emerald',
    },
    {
      id: 'complaints',
      label: t.nav.complaints,
      icon: MessageSquareWarning,
      badge: badges?.openComplaints,
      badgeTone: 'red',
    },
    { id: 'users', label: t.nav.users, icon: Users },
    { id: 'winchTypes', label: t.nav.winchTypes, icon: Truck },
  ];

  const activeNav = navItems.find((item) => item.id === activeRoute);

  const handleSelectRoute = (route: AdminRoute) => {
    onNavigate(route);
    setMobileMenuOpen(false);
  };

  const renderSidebarContent = () => (
    <div className="flex h-full flex-col bg-[#0F172A] text-slate-100">
      {/* Brand Header */}
      <div className="flex items-center justify-between border-b border-slate-800/90 px-5 py-5">
        <div className="flex items-center gap-3">
          <div className="flex h-11 w-11 items-center justify-center rounded-xl bg-amber-500 text-slate-950 shadow-lg shadow-amber-500/20">
            <Truck className="h-6 w-6 stroke-[2.25]" />
          </div>
          <div>
            <div className="flex items-center gap-2">
              <span className="text-lg font-extrabold tracking-tight text-white">
                {t.brand.name}
              </span>
              <span className="rounded-md bg-amber-500/15 px-1.5 py-0.5 text-[10px] font-bold uppercase tracking-wider text-amber-400">
                ADMIN
              </span>
            </div>
            <p className="text-xs text-slate-400">{t.brand.subtitle}</p>
          </div>
        </div>
        <button
          type="button"
          onClick={() => setMobileMenuOpen(false)}
          className="rounded-lg p-1.5 text-slate-400 hover:bg-slate-800 hover:text-white lg:hidden"
        >
          <X className="h-5 w-5" />
        </button>
      </div>

      {/* Navigation Links */}
      <nav className="flex-1 space-y-1.5 overflow-y-auto px-3 py-4">
        {navItems.map((item) => {
          const Icon = item.icon;
          const isActive = item.id === activeRoute;
          return (
            <button
              key={item.id}
              type="button"
              onClick={() => handleSelectRoute(item.id)}
              className={`group flex w-full items-center justify-between rounded-xl px-3.5 py-2.5 text-sm font-semibold transition-all ${
                isActive
                  ? 'bg-amber-500 text-slate-950 shadow-md shadow-amber-500/15'
                  : 'text-slate-300 hover:bg-slate-800/80 hover:text-white'
              }`}
            >
              <span className="flex items-center gap-3">
                <Icon
                  className={`h-5 w-5 shrink-0 ${
                    isActive ? 'text-slate-950' : 'text-slate-400 group-hover:text-amber-400'
                  }`}
                />
                <span className="truncate">{item.label}</span>
              </span>
              {typeof item.badge === 'number' && item.badge > 0 && (
                <span
                  className={`rounded-full px-2 py-0.5 text-xs font-bold ${
                    isActive
                      ? 'bg-slate-950/20 text-slate-950'
                      : item.badgeTone === 'red'
                        ? 'bg-red-500/20 text-red-300'
                        : item.badgeTone === 'emerald'
                          ? 'bg-emerald-500/20 text-emerald-300'
                          : 'bg-amber-500/20 text-amber-300'
                  }`}
                >
                  {item.badge}
                </span>
              )}
            </button>
          );
        })}
      </nav>

      {/* Footer Admin Info */}
      <div className="border-t border-slate-800/90 p-4">
        <div className="flex items-center gap-3 rounded-xl bg-slate-900/90 p-3">
          <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-amber-500/20 text-sm font-bold text-amber-400">
            {(profile?.full_name || user?.email || 'A').slice(0, 1).toUpperCase()}
          </div>
          <div className="min-w-0 flex-1">
            <p className="truncate text-sm font-semibold text-white">
              {profile?.full_name || t.common.adminBadge}
            </p>
            <p className="truncate text-xs text-slate-400">{user?.email}</p>
          </div>
        </div>
        <button
          type="button"
          onClick={() => void signOut()}
          className="mt-3 flex w-full items-center justify-center gap-2 rounded-xl border border-slate-700/80 bg-slate-800/60 px-3 py-2 text-xs font-semibold text-slate-200 transition hover:border-red-500/50 hover:bg-red-500/15 hover:text-red-300"
        >
          <LogOut className="h-4 w-4" />
          <span>{t.common.signOut}</span>
        </button>
      </div>
    </div>
  );

  return (
    <div className="flex min-h-screen bg-slate-50 text-slate-900">
      {/* Desktop Sidebar */}
      <aside className="hidden w-72 shrink-0 lg:block">
        <div className="sticky top-0 h-screen">{renderSidebarContent()}</div>
      </aside>

      {/* Mobile Sidebar Drawer */}
      {mobileMenuOpen && (
        <div className="fixed inset-0 z-50 flex lg:hidden">
          <div
            className="fixed inset-0 bg-slate-950/60 backdrop-blur-xs"
            onClick={() => setMobileMenuOpen(false)}
          />
          <div className="relative z-10 h-full w-72 max-w-[85vw] shadow-2xl">
            {renderSidebarContent()}
          </div>
        </div>
      )}

      {/* Main Content Area */}
      <div className="flex min-w-0 flex-1 flex-col">
        {/* Topbar */}
        <header className="sticky top-0 z-30 flex h-16 items-center justify-between border-b border-slate-200 bg-white/90 px-4 backdrop-blur-md sm:px-6">
          <div className="flex items-center gap-3">
            <button
              type="button"
              onClick={() => setMobileMenuOpen(true)}
              className="rounded-xl border border-slate-200 p-2 text-slate-600 hover:bg-slate-100 lg:hidden"
              aria-label="Open menu"
            >
              <Menu className="h-5 w-5" />
            </button>
            <h1 className="text-base font-bold text-slate-900 sm:text-lg">
              {activeNav?.label ?? t.nav.overview}
            </h1>
          </div>

          <div className="flex items-center gap-2.5">
            <div className="hidden items-center gap-1.5 rounded-full border border-emerald-200 bg-emerald-50 px-3 py-1 text-xs font-semibold text-emerald-700 sm:flex">
              <Radio className="h-3.5 w-3.5 animate-pulse text-emerald-500" />
              <span>{t.common.liveSync}</span>
            </div>

            <button
              type="button"
              onClick={toggleLocale}
              className="flex items-center gap-1.5 rounded-xl border border-slate-200 bg-white px-3 py-1.5 text-xs font-bold text-slate-700 shadow-2xs transition hover:border-amber-400 hover:bg-amber-50 hover:text-slate-900"
            >
              <Languages className="h-4 w-4 text-amber-600" />
              <span>{t.common.switchLang}</span>
            </button>
          </div>
        </header>

        {/* Page Body */}
        <main className="mx-auto w-full max-w-[1600px] flex-1 p-4 sm:p-6">{children}</main>
      </div>
    </div>
  );
}
