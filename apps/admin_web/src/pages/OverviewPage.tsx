import React, { useCallback, useEffect, useRef, useState } from 'react';
import {
  Navigation,
  Search,
  Radio,
  ShieldAlert,
  CheckCircle2,
  Banknote,
  MessageSquareWarning,
  Star,
  Users,
  Truck,
  UserCheck,
  RefreshCw,
  ArrowUpRight,
  Activity,
} from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useLanguage } from '../i18n/LanguageContext';
import { formatCurrency, formatDateTime, formatNumber } from '../lib/format';
import type { DashboardStats } from '../types/database';
import type { AdminRoute } from '../components/Layout';

interface OverviewPageProps {
  onNavigate: (route: AdminRoute) => void;
  onStatsLoaded?: (stats: DashboardStats) => void;
}

export function OverviewPage({ onNavigate, onStatsLoaded }: OverviewPageProps) {
  const { locale, t } = useLanguage();
  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [lastUpdated, setLastUpdated] = useState<string | null>(null);
  const debounceRef = useRef<number | null>(null);

  const fetchStats = useCallback(
    async (silent = false) => {
      if (silent) setRefreshing(true);
      else setLoading(true);
      setError(null);

      const { data, error: rpcError } = await supabase.rpc('admin_get_dashboard_stats');
      if (rpcError) {
        setError(rpcError.message);
      } else if (data) {
        const parsed = data as DashboardStats;
        setStats(parsed);
        setLastUpdated(new Date().toISOString());
        onStatsLoaded?.(parsed);
      }

      setLoading(false);
      setRefreshing(false);
    },
    [onStatsLoaded]
  );

  useEffect(() => {
    void fetchStats(false);

    const scheduleRefresh = () => {
      if (debounceRef.current) window.clearTimeout(debounceRef.current);
      debounceRef.current = window.setTimeout(() => {
        void fetchStats(true);
      }, 450);
    };

    const channel = supabase
      .channel('admin-overview-realtime')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'rescue_requests' }, scheduleRefresh)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'drivers' }, scheduleRefresh)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'driver_documents' }, scheduleRefresh)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'complaints' }, scheduleRefresh)
      .subscribe();

    return () => {
      if (debounceRef.current) window.clearTimeout(debounceRef.current);
      void supabase.removeChannel(channel);
    };
  }, [fetchStats]);

  const approvalRate =
    stats && stats.total_drivers > 0
      ? Math.round((stats.approved_drivers / stats.total_drivers) * 100)
      : 0;

  const primaryKpis: Array<{
    key: string;
    label: string;
    value: string;
    icon: React.ComponentType<{ className?: string }>;
    accent: string;
    bg: string;
    onClick?: () => void;
    highlight?: boolean;
  }> = [
    {
      key: 'activeTrips',
      label: t.overview.kpi.activeTrips,
      value: formatNumber(stats?.active_trips_now, locale),
      icon: Navigation,
      accent: 'text-emerald-600',
      bg: 'bg-emerald-50',
      onClick: () => onNavigate('trips'),
    },
    {
      key: 'searchingRequests',
      label: t.overview.kpi.searchingRequests,
      value: formatNumber(stats?.searching_requests_now, locale),
      icon: Search,
      accent: 'text-amber-600',
      bg: 'bg-amber-50',
      onClick: () => onNavigate('trips'),
      highlight: (stats?.searching_requests_now ?? 0) > 0,
    },
    {
      key: 'onlineDrivers',
      label: t.overview.kpi.onlineDrivers,
      value: formatNumber(stats?.online_drivers_now, locale),
      icon: Radio,
      accent: 'text-sky-600',
      bg: 'bg-sky-50',
      onClick: () => onNavigate('drivers'),
    },
    {
      key: 'pendingApprovals',
      label: t.overview.kpi.pendingApprovals,
      value: formatNumber(stats?.pending_driver_approvals, locale),
      icon: ShieldAlert,
      accent: 'text-amber-600',
      bg: 'bg-amber-50',
      onClick: () => onNavigate('drivers'),
      highlight: (stats?.pending_driver_approvals ?? 0) > 0,
    },
    {
      key: 'deliveredToday',
      label: t.overview.kpi.deliveredToday,
      value: formatNumber(stats?.delivered_today, locale),
      icon: CheckCircle2,
      accent: 'text-emerald-600',
      bg: 'bg-emerald-50',
    },
    {
      key: 'revenueToday',
      label: t.overview.kpi.revenueToday,
      value: formatCurrency(stats?.revenue_today, locale),
      icon: Banknote,
      accent: 'text-slate-900',
      bg: 'bg-amber-100/70',
    },
    {
      key: 'openComplaints',
      label: t.overview.kpi.openComplaints,
      value: formatNumber(stats?.open_complaints, locale),
      icon: MessageSquareWarning,
      accent: 'text-red-600',
      bg: 'bg-red-50',
      onClick: () => onNavigate('complaints'),
      highlight: (stats?.open_complaints ?? 0) > 0,
    },
    {
      key: 'avgRating',
      label: t.overview.kpi.avgRating,
      value: `${Number(stats?.average_driver_rating ?? 5).toFixed(2)} ★`,
      icon: Star,
      accent: 'text-amber-500',
      bg: 'bg-amber-50',
    },
  ];

  const quickActions: Array<{
    route: AdminRoute;
    title: string;
    desc: string;
    count?: number;
    tone: 'amber' | 'emerald' | 'red' | 'slate';
  }> = [
    {
      route: 'drivers',
      title: t.overview.goToApprovals,
      desc: t.overview.goToApprovalsDesc,
      count: stats?.pending_driver_approvals,
      tone: 'amber',
    },
    {
      route: 'trips',
      title: t.overview.goToTrips,
      desc: t.overview.goToTripsDesc,
      count: (stats?.active_trips_now ?? 0) + (stats?.searching_requests_now ?? 0),
      tone: 'emerald',
    },
    {
      route: 'complaints',
      title: t.overview.goToComplaints,
      desc: t.overview.goToComplaintsDesc,
      count: stats?.open_complaints,
      tone: 'red',
    },
    {
      route: 'winchTypes',
      title: t.overview.goToPricing,
      desc: t.overview.goToPricingDesc,
      tone: 'slate',
    },
  ];

  return (
    <div className="space-y-6">
      {/* Header Banner */}
      <div className="flex flex-col justify-between gap-4 rounded-2xl bg-[#0F172A] p-6 text-white shadow-lg sm:flex-row sm:items-center">
        <div>
          <h2 className="text-xl font-extrabold tracking-tight sm:text-2xl">
            {t.overview.title}
          </h2>
          <p className="mt-1 text-sm text-slate-300">{t.overview.subtitle}</p>
        </div>
        <div className="flex flex-wrap items-center gap-3">
          {lastUpdated && (
            <span className="text-xs text-slate-400">
              {t.common.lastUpdated}: {formatDateTime(lastUpdated, locale)}
            </span>
          )}
          <button
            type="button"
            onClick={() => void fetchStats(true)}
            disabled={refreshing}
            className="flex items-center gap-2 rounded-xl bg-amber-500 px-4 py-2 text-xs font-extrabold text-slate-950 transition hover:bg-amber-400 disabled:opacity-60"
          >
            <RefreshCw className={`h-4 w-4 ${refreshing ? 'animate-spin' : ''}`} />
            <span>{t.common.refresh}</span>
          </button>
        </div>
      </div>

      {error && (
        <div className="rounded-xl border border-red-200 bg-red-50 p-4 text-sm font-medium text-red-700">
          {error}
        </div>
      )}

      {/* Primary KPI Grid */}
      {loading && !stats ? (
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
          {Array.from({ length: 8 }).map((_, idx) => (
            <div
              key={idx}
              className="h-32 animate-pulse rounded-2xl border border-slate-200 bg-white p-5"
            />
          ))}
        </div>
      ) : (
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
          {primaryKpis.map((card) => {
            const Icon = card.icon;
            return (
              <button
                key={card.key}
                type="button"
                onClick={card.onClick}
                disabled={!card.onClick}
                className={`group flex flex-col justify-between rounded-2xl border bg-white p-5 text-start shadow-2xs transition ${
                  card.highlight
                    ? 'border-amber-300 ring-1 ring-amber-200/70'
                    : 'border-slate-200'
                } ${card.onClick ? 'cursor-pointer hover:-translate-y-0.5 hover:border-amber-400 hover:shadow-md' : 'cursor-default'}`}
              >
                <div className="flex items-center justify-between gap-3">
                  <div className={`flex h-11 w-11 items-center justify-center rounded-xl ${card.bg} ${card.accent}`}>
                    <Icon className="h-5 w-5" />
                  </div>
                  {card.onClick && (
                    <ArrowUpRight className="h-4 w-4 text-slate-300 transition group-hover:text-amber-500 rtl:-scale-x-100" />
                  )}
                </div>
                <div className="mt-4">
                  <p className="text-xs font-semibold text-slate-500">{card.label}</p>
                  <p className="mt-1 text-2xl font-extrabold tracking-tight text-slate-900">
                    {card.value}
                  </p>
                </div>
              </button>
            );
          })}
        </div>
      )}

      {/* Secondary Row: Fleet Health & Quick Actions */}
      <div className="grid grid-cols-1 gap-6 lg:grid-cols-3">
        {/* Fleet & Platform Summary */}
        <div className="flex flex-col justify-between rounded-2xl border border-slate-200 bg-white p-6 shadow-2xs">
          <div>
            <div className="flex items-center gap-2">
              <Activity className="h-5 w-5 text-amber-500" />
              <h3 className="text-base font-bold text-slate-900">{t.overview.fleetHealth}</h3>
            </div>

            <div className="mt-5 grid grid-cols-3 gap-3">
              <div className="rounded-xl bg-slate-50 p-3 text-center">
                <Users className="mx-auto h-4 w-4 text-sky-600" />
                <p className="mt-1.5 text-lg font-extrabold text-slate-900">
                  {formatNumber(stats?.total_customers, locale)}
                </p>
                <p className="text-[11px] font-semibold text-slate-500">
                  {t.overview.kpi.totalCustomers}
                </p>
              </div>
              <div className="rounded-xl bg-slate-50 p-3 text-center">
                <Truck className="mx-auto h-4 w-4 text-amber-600" />
                <p className="mt-1.5 text-lg font-extrabold text-slate-900">
                  {formatNumber(stats?.total_drivers, locale)}
                </p>
                <p className="text-[11px] font-semibold text-slate-500">
                  {t.overview.kpi.totalDrivers}
                </p>
              </div>
              <div className="rounded-xl bg-slate-50 p-3 text-center">
                <UserCheck className="mx-auto h-4 w-4 text-emerald-600" />
                <p className="mt-1.5 text-lg font-extrabold text-slate-900">
                  {formatNumber(stats?.approved_drivers, locale)}
                </p>
                <p className="text-[11px] font-semibold text-slate-500">
                  {t.overview.kpi.approvedDrivers}
                </p>
              </div>
            </div>

            <div className="mt-5 space-y-3">
              <div>
                <div className="flex items-center justify-between text-xs font-semibold">
                  <span className="text-slate-600">{t.overview.approvalRate}</span>
                  <span className="text-slate-900">{approvalRate}%</span>
                </div>
                <div className="mt-1.5 h-2 w-full overflow-hidden rounded-full bg-slate-100">
                  <div
                    className="h-full rounded-full bg-emerald-500 transition-all duration-500"
                    style={{ width: `${approvalRate}%` }}
                  />
                </div>
              </div>
            </div>
          </div>

          <div className="mt-6 rounded-xl border border-slate-200/80 bg-slate-50 p-3.5">
            <p className="text-xs font-bold text-slate-800">{t.overview.realtimeFeed}</p>
            <p className="mt-1 text-xs leading-relaxed text-slate-500">
              {t.overview.realtimeFeedDesc}
            </p>
          </div>
        </div>

        {/* Quick Actions Grid */}
        <div className="rounded-2xl border border-slate-200 bg-white p-6 shadow-2xs lg:col-span-2">
          <h3 className="text-base font-bold text-slate-900">{t.overview.quickActions}</h3>
          <div className="mt-4 grid grid-cols-1 gap-3.5 sm:grid-cols-2">
            {quickActions.map((item) => (
              <button
                key={item.route}
                type="button"
                onClick={() => onNavigate(item.route)}
                className="group flex flex-col justify-between rounded-2xl border border-slate-200 bg-slate-50/60 p-4 text-start transition hover:border-amber-400 hover:bg-amber-50/40"
              >
                <div className="flex items-start justify-between gap-2">
                  <h4 className="text-sm font-bold text-slate-900 group-hover:text-amber-700">
                    {item.title}
                  </h4>
                  {typeof item.count === 'number' && (
                    <span
                      className={`rounded-full px-2.5 py-0.5 text-xs font-extrabold ${
                        item.tone === 'red'
                          ? 'bg-red-100 text-red-700'
                          : item.tone === 'emerald'
                            ? 'bg-emerald-100 text-emerald-700'
                            : 'bg-amber-100 text-amber-800'
                      }`}
                    >
                      {formatNumber(item.count, locale)}
                    </span>
                  )}
                </div>
                <p className="mt-2 text-xs leading-relaxed text-slate-600">{item.desc}</p>
              </button>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
