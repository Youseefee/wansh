import { useCallback, useEffect, useMemo, useState } from 'react';
import { Search, RefreshCw, UserCheck, UserX } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useLanguage } from '../i18n/LanguageContext';
import { useAuth } from '../contexts/AuthContext';
import { useToast } from '../components/Toast';
import { formatDate } from '../lib/format';
import { Badge, RoleBadge } from '../components/StatusBadge';
import { ConfirmModal } from '../components/ConfirmModal';
import type { AppRole, Profile } from '../types/database';

type RoleFilter = 'all' | AppRole;

export function UsersPage() {
  const { locale, t } = useLanguage();
  const { user: currentUser } = useAuth();
  const { showToast } = useToast();

  const [profiles, setProfiles] = useState<Profile[]>([]);
  const [loading, setLoading] = useState(true);
  const [roleFilter, setRoleFilter] = useState<RoleFilter>('all');
  const [search, setSearch] = useState('');
  const [toggleTarget, setToggleTarget] = useState<Profile | null>(null);
  const [busy, setBusy] = useState(false);

  const fetchProfiles = useCallback(async () => {
    setLoading(true);
    const { data, error } = await supabase
      .from('profiles')
      .select('*')
      .order('created_at', { ascending: false });

    if (error) {
      showToast(error.message, 'error');
    } else {
      setProfiles((data ?? []) as Profile[]);
    }
    setLoading(false);
  }, [showToast]);

  useEffect(() => {
    void fetchProfiles();
  }, [fetchProfiles]);

  const counts = useMemo(() => {
    const map: Record<RoleFilter, number> = {
      all: profiles.length,
      customer: 0,
      driver: 0,
      admin: 0,
    };
    for (const p of profiles) {
      map[p.role] = (map[p.role] ?? 0) + 1;
    }
    return map;
  }, [profiles]);

  const filteredProfiles = useMemo(() => {
    const q = search.trim().toLowerCase();
    return profiles.filter((p) => {
      if (roleFilter !== 'all' && p.role !== roleFilter) return false;
      if (!q) return true;
      const haystack = [p.full_name, p.phone, p.email]
        .filter(Boolean)
        .join(' ')
        .toLowerCase();
      return haystack.includes(q);
    });
  }, [profiles, roleFilter, search]);

  const handleConfirmToggle = async () => {
    if (!toggleTarget) return;
    setBusy(true);
    const nextActive = !toggleTarget.is_active;
    const { error } = await supabase.rpc('admin_set_user_active', {
      p_user_id: toggleTarget.id,
      p_is_active: nextActive,
    });
    setBusy(false);

    if (error) {
      showToast(error.message, 'error');
      return;
    }

    showToast(t.users.updatedToast, 'success');
    setProfiles((prev) =>
      prev.map((item) => (item.id === toggleTarget.id ? { ...item, is_active: nextActive } : item))
    );
    setToggleTarget(null);
  };

  const tabs: RoleFilter[] = ['all', 'customer', 'driver', 'admin'];

  return (
    <div className="space-y-5">
      {/* Header */}
      <div className="flex flex-col justify-between gap-3 sm:flex-row sm:items-center">
        <div>
          <h2 className="text-xl font-extrabold text-slate-900">{t.users.title}</h2>
          <p className="mt-0.5 text-sm text-slate-500">{t.users.subtitle}</p>
        </div>
        <button
          type="button"
          onClick={() => void fetchProfiles()}
          className="inline-flex items-center gap-2 self-start rounded-xl border border-slate-200 bg-white px-3.5 py-2 text-xs font-bold text-slate-700 shadow-2xs hover:bg-slate-50"
        >
          <RefreshCw className={`h-4 w-4 ${loading ? 'animate-spin' : ''}`} />
          <span>{t.common.refresh}</span>
        </button>
      </div>

      {/* Filter Tabs + Search */}
      <div className="flex flex-col gap-3 rounded-2xl border border-slate-200 bg-white p-4 shadow-2xs">
        <div className="flex flex-wrap items-center gap-2">
          {tabs.map((tab) => {
            const active = roleFilter === tab;
            return (
              <button
                key={tab}
                type="button"
                onClick={() => setRoleFilter(tab)}
                className={`inline-flex items-center gap-1.5 rounded-xl px-3 py-1.5 text-xs font-bold transition ${
                  active
                    ? 'bg-slate-900 text-white'
                    : 'bg-slate-100 text-slate-600 hover:bg-slate-200'
                }`}
              >
                <span>{t.users.tabs[tab]}</span>
                <span
                  className={`rounded-full px-1.5 py-0.2 text-[11px] ${
                    active ? 'bg-amber-500 text-slate-950' : 'bg-white text-slate-700'
                  }`}
                >
                  {counts[tab]}
                </span>
              </button>
            );
          })}
        </div>

        <div className="relative">
          <Search className="pointer-events-none absolute top-1/2 start-3.5 h-4 w-4 -translate-y-1/2 text-slate-400" />
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder={t.users.searchPlaceholder}
            className="w-full rounded-xl border border-slate-200 bg-slate-50/60 py-2.5 ps-10 pe-4 text-sm text-slate-900 focus:border-amber-500 focus:bg-white focus:outline-none focus:ring-2 focus:ring-amber-500/20"
          />
        </div>
      </div>

      {/* Users Table */}
      <div className="overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-2xs">
        <div className="overflow-x-auto">
          <table className="w-full text-start text-sm">
            <thead className="border-b border-slate-200 bg-slate-50 text-xs font-bold text-slate-600">
              <tr>
                <th className="px-4 py-3.5 text-start">{t.users.table.user}</th>
                <th className="px-4 py-3.5 text-start">{t.users.table.contact}</th>
                <th className="px-4 py-3.5 text-start">{t.users.table.role}</th>
                <th className="px-4 py-3.5 text-start">{t.users.table.locale}</th>
                <th className="px-4 py-3.5 text-start">{t.users.table.status}</th>
                <th className="px-4 py-3.5 text-start">{t.users.table.joined}</th>
                <th className="px-4 py-3.5 text-end">{t.common.actions}</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {loading ? (
                <tr>
                  <td colSpan={7} className="px-4 py-12 text-center text-sm text-slate-500">
                    {t.common.loading}
                  </td>
                </tr>
              ) : filteredProfiles.length === 0 ? (
                <tr>
                  <td colSpan={7} className="px-4 py-12 text-center text-sm text-slate-500">
                    {t.common.noData}
                  </td>
                </tr>
              ) : (
                filteredProfiles.map((p) => {
                  const isSelf = p.id === currentUser?.id;
                  return (
                    <tr key={p.id} className="transition hover:bg-slate-50/80">
                      <td className="px-4 py-3.5">
                        <div className="flex items-center gap-3">
                          <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-slate-900 text-xs font-bold text-amber-400">
                            {(p.full_name || p.email || 'U').slice(0, 1).toUpperCase()}
                          </div>
                          <div>
                            <p className="font-bold text-slate-900">{p.full_name || '—'}</p>
                            <p className="font-mono text-[11px] text-slate-400">
                              {p.id.slice(0, 8)}...
                            </p>
                          </div>
                        </div>
                      </td>
                      <td className="px-4 py-3.5">
                        <p className="font-mono text-xs font-semibold text-slate-800" dir="ltr">
                          {p.phone || '—'}
                        </p>
                        <p className="text-xs text-slate-500" dir="ltr">
                          {p.email || '—'}
                        </p>
                      </td>
                      <td className="px-4 py-3.5">
                        <RoleBadge role={p.role} />
                      </td>
                      <td className="px-4 py-3.5">
                        <span className="rounded-md bg-slate-100 px-2 py-0.5 text-xs font-bold uppercase text-slate-600">
                          {p.locale}
                        </span>
                      </td>
                      <td className="px-4 py-3.5">
                        <Badge
                          label={p.is_active ? t.common.active : t.common.inactive}
                          tone={p.is_active ? 'emerald' : 'red'}
                          dot
                        />
                      </td>
                      <td className="px-4 py-3.5 text-xs text-slate-500">
                        {formatDate(p.created_at, locale)}
                      </td>
                      <td className="px-4 py-3.5 text-end">
                        <button
                          type="button"
                          disabled={isSelf}
                          title={isSelf ? t.users.selfGuard : undefined}
                          onClick={() => setToggleTarget(p)}
                          className={`inline-flex items-center gap-1.5 rounded-xl px-3 py-1.5 text-xs font-bold transition disabled:cursor-not-allowed disabled:opacity-40 ${
                            p.is_active
                              ? 'border border-red-200 bg-red-50 text-red-700 hover:bg-red-100'
                              : 'border border-emerald-200 bg-emerald-50 text-emerald-700 hover:bg-emerald-100'
                          }`}
                        >
                          {p.is_active ? (
                            <>
                              <UserX className="h-3.5 w-3.5" />
                              <span>{t.users.suspend}</span>
                            </>
                          ) : (
                            <>
                              <UserCheck className="h-3.5 w-3.5" />
                              <span>{t.users.activate}</span>
                            </>
                          )}
                        </button>
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Confirm Toggle Modal */}
      <ConfirmModal
        open={Boolean(toggleTarget)}
        title={
          toggleTarget?.is_active ? t.users.confirmSuspendTitle : t.users.confirmActivateTitle
        }
        description={
          toggleTarget?.is_active ? t.users.confirmSuspendDesc : t.users.confirmActivateDesc
        }
        confirmLabel={toggleTarget?.is_active ? t.users.suspend : t.users.activate}
        variant={toggleTarget?.is_active ? 'danger' : 'primary'}
        loading={busy}
        onCancel={() => setToggleTarget(null)}
        onConfirm={handleConfirmToggle}
      />
    </div>
  );
}
