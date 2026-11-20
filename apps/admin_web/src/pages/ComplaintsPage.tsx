import { useCallback, useEffect, useMemo, useState } from 'react';
import {
  Search,
  RefreshCw,
  Eye,
  X,
  FileText,
  ExternalLink,
  CheckCircle2,
  MessageSquareWarning,
  Link2,
} from 'lucide-react';
import { supabase, getSignedPrivateUrl, isPdfPath } from '../lib/supabase';
import { useLanguage } from '../i18n/LanguageContext';
import { useToast } from '../components/Toast';
import { formatDateTime } from '../lib/format';
import { ComplaintStatusBadge, RoleBadge } from '../components/StatusBadge';
import type { AdminComplaintItem, ComplaintStatus } from '../types/database';

type FilterTab = 'all' | ComplaintStatus;

export function ComplaintsPage() {
  const { locale, t } = useLanguage();
  const { showToast } = useToast();

  const [complaints, setComplaints] = useState<AdminComplaintItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [statusFilter, setStatusFilter] = useState<FilterTab>('open');
  const [search, setSearch] = useState('');
  const [selectedId, setSelectedId] = useState<string | null>(null);

  // Resolution form state
  const [nextStatus, setNextStatus] = useState<ComplaintStatus>('in_progress');
  const [adminNotes, setAdminNotes] = useState('');
  const [saving, setSaving] = useState(false);

  // Evidence signed URLs
  const [evidenceUrls, setEvidenceUrls] = useState<Array<{ path: string; url: string | null }>>([]);
  const [loadingEvidence, setLoadingEvidence] = useState(false);

  const fetchComplaints = useCallback(
    async (silent = false) => {
      if (!silent) setLoading(true);
      const { data, error } = await supabase
        .from('v_admin_complaints_queue')
        .select('*')
        .order('created_at', { ascending: false });

      if (error) {
        showToast(error.message, 'error');
      } else {
        setComplaints((data ?? []) as AdminComplaintItem[]);
      }
      setLoading(false);
    },
    [showToast]
  );

  useEffect(() => {
    void fetchComplaints(false);

    const channel = supabase
      .channel('admin-complaints-realtime')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'complaints' }, () => {
        void fetchComplaints(true);
      })
      .subscribe();

    return () => {
      void supabase.removeChannel(channel);
    };
  }, [fetchComplaints]);

  const selectedComplaint = useMemo(
    () => complaints.find((item) => item.id === selectedId) ?? null,
    [complaints, selectedId]
  );

  useEffect(() => {
    if (!selectedComplaint) {
      setEvidenceUrls([]);
      return;
    }

    setNextStatus(selectedComplaint.status);
    setAdminNotes(selectedComplaint.admin_notes ?? '');

    let cancelled = false;
    async function loadEvidence(paths: string[]) {
      setLoadingEvidence(true);
      const resolved = await Promise.all(
        paths.map(async (path) => ({
          path,
          url: await getSignedPrivateUrl('complaint-evidence', path, 3600),
        }))
      );
      if (!cancelled) {
        setEvidenceUrls(resolved);
        setLoadingEvidence(false);
      }
    }

    void loadEvidence(selectedComplaint.evidence_paths ?? []);
    return () => {
      cancelled = true;
    };
  }, [selectedComplaint]);

  const counts = useMemo(() => {
    const map: Record<FilterTab, number> = {
      all: complaints.length,
      open: 0,
      in_progress: 0,
      resolved: 0,
      dismissed: 0,
    };
    for (const item of complaints) {
      map[item.status] = (map[item.status] ?? 0) + 1;
    }
    return map;
  }, [complaints]);

  const filteredComplaints = useMemo(() => {
    const q = search.trim().toLowerCase();
    return complaints.filter((item) => {
      if (statusFilter !== 'all' && item.status !== statusFilter) return false;
      if (!q) return true;
      const haystack = [
        item.complaint_code,
        item.request_code,
        item.subject,
        item.description,
        item.reporter_name,
        item.reporter_phone,
        item.reported_user_name,
      ]
        .filter(Boolean)
        .join(' ')
        .toLowerCase();
      return haystack.includes(q);
    });
  }, [complaints, statusFilter, search]);

  const handleResolve = async () => {
    if (!selectedComplaint) return;
    setSaving(true);
    const { error } = await supabase.rpc('admin_resolve_complaint', {
      p_complaint_id: selectedComplaint.id,
      p_status: nextStatus,
      p_admin_notes: adminNotes.trim() || null,
    });
    setSaving(false);

    if (error) {
      showToast(error.message, 'error');
      return;
    }
    showToast(t.complaints.drawer.updatedToast, 'success');
    await fetchComplaints(true);
  };

  const tabs: FilterTab[] = ['open', 'in_progress', 'resolved', 'dismissed', 'all'];

  return (
    <div className="space-y-5">
      {/* Header */}
      <div className="flex flex-col justify-between gap-3 sm:flex-row sm:items-center">
        <div>
          <h2 className="text-xl font-extrabold text-slate-900">{t.complaints.title}</h2>
          <p className="mt-0.5 text-sm text-slate-500">{t.complaints.subtitle}</p>
        </div>
        <button
          type="button"
          onClick={() => void fetchComplaints(false)}
          className="inline-flex items-center gap-2 self-start rounded-xl border border-slate-200 bg-white px-3.5 py-2 text-xs font-bold text-slate-700 shadow-2xs hover:bg-slate-50"
        >
          <RefreshCw className={`h-4 w-4 ${loading ? 'animate-spin' : ''}`} />
          <span>{t.common.refresh}</span>
        </button>
      </div>

      {/* Filter Bar */}
      <div className="flex flex-col gap-3 rounded-2xl border border-slate-200 bg-white p-4 shadow-2xs">
        <div className="flex flex-wrap items-center gap-2">
          {tabs.map((tab) => {
            const active = statusFilter === tab;
            return (
              <button
                key={tab}
                type="button"
                onClick={() => setStatusFilter(tab)}
                className={`inline-flex items-center gap-1.5 rounded-xl px-3 py-1.5 text-xs font-bold transition ${
                  active
                    ? 'bg-slate-900 text-white'
                    : 'bg-slate-100 text-slate-600 hover:bg-slate-200'
                }`}
              >
                <span>{t.complaints.tabs[tab]}</span>
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
            placeholder={t.complaints.searchPlaceholder}
            className="w-full rounded-xl border border-slate-200 bg-slate-50/60 py-2.5 ps-10 pe-4 text-sm text-slate-900 focus:border-amber-500 focus:bg-white focus:outline-none focus:ring-2 focus:ring-amber-500/20"
          />
        </div>
      </div>

      {/* Complaints List Table */}
      <div className="overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-2xs">
        <div className="overflow-x-auto">
          <table className="w-full text-start text-sm">
            <thead className="border-b border-slate-200 bg-slate-50 text-xs font-bold text-slate-600">
              <tr>
                <th className="px-4 py-3.5 text-start">#</th>
                <th className="px-4 py-3.5 text-start">{t.complaints.drawer.description}</th>
                <th className="px-4 py-3.5 text-start">{t.complaints.drawer.reporter}</th>
                <th className="px-4 py-3.5 text-start">{t.complaints.drawer.linkedTrip}</th>
                <th className="px-4 py-3.5 text-start">{t.drivers.table.status}</th>
                <th className="px-4 py-3.5 text-end">{t.common.actions}</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {loading ? (
                <tr>
                  <td colSpan={6} className="px-4 py-12 text-center text-sm text-slate-500">
                    {t.common.loading}
                  </td>
                </tr>
              ) : filteredComplaints.length === 0 ? (
                <tr>
                  <td colSpan={6} className="px-4 py-12 text-center text-sm text-slate-500">
                    {t.common.noData}
                  </td>
                </tr>
              ) : (
                filteredComplaints.map((item) => (
                  <tr key={item.id} className="transition hover:bg-amber-50/30">
                    <td className="px-4 py-3.5">
                      <p className="font-mono text-xs font-extrabold text-slate-900">
                        {item.complaint_code}
                      </p>
                      <p className="mt-0.5 text-[11px] text-slate-400">
                        {formatDateTime(item.created_at, locale)}
                      </p>
                    </td>
                    <td className="max-w-sm px-4 py-3.5">
                      <span className="inline-block rounded-md bg-slate-100 px-2 py-0.5 text-[11px] font-bold text-slate-700">
                        {t.complaints.categories[item.category]}
                      </span>
                      <p className="mt-1 font-bold text-slate-900 line-clamp-1">{item.subject}</p>
                      <p className="text-xs text-slate-500 line-clamp-1">{item.description}</p>
                    </td>
                    <td className="px-4 py-3.5">
                      <div className="flex items-center gap-1.5">
                        <span className="font-bold text-slate-900">{item.reporter_name}</span>
                        <RoleBadge role={item.reporter_role} />
                      </div>
                      <p className="font-mono text-xs text-slate-500" dir="ltr">
                        {item.reporter_phone || '—'}
                      </p>
                    </td>
                    <td className="px-4 py-3.5">
                      {item.request_code ? (
                        <span className="inline-flex items-center gap-1 rounded-lg bg-amber-50 px-2.5 py-1 font-mono text-xs font-bold text-amber-800">
                          <Link2 className="h-3 w-3" />
                          {item.request_code}
                        </span>
                      ) : (
                        <span className="text-xs text-slate-400">—</span>
                      )}
                    </td>
                    <td className="px-4 py-3.5">
                      <ComplaintStatusBadge status={item.status} />
                    </td>
                    <td className="px-4 py-3.5 text-end">
                      <button
                        type="button"
                        onClick={() => setSelectedId(item.id)}
                        className="inline-flex items-center gap-1.5 rounded-xl bg-slate-900 px-3 py-1.5 text-xs font-bold text-white transition hover:bg-amber-500 hover:text-slate-950"
                      >
                        <Eye className="h-3.5 w-3.5" />
                        <span>{t.common.details}</span>
                      </button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Complaint Investigation Drawer */}
      {selectedComplaint && (
        <div className="fixed inset-0 z-40 flex justify-end bg-slate-950/55 backdrop-blur-xs">
          <div className="fixed inset-0" onClick={() => setSelectedId(null)} />
          <div className="relative z-10 flex h-full w-full max-w-2xl flex-col bg-white shadow-2xl">
            {/* Drawer Header */}
            <div className="flex items-center justify-between border-b border-slate-200 bg-[#0F172A] px-6 py-4 text-white">
              <div className="flex items-center gap-3">
                <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-amber-500 text-slate-950">
                  <MessageSquareWarning className="h-5 w-5" />
                </div>
                <div>
                  <div className="flex items-center gap-2">
                    <h3 className="font-mono text-base font-extrabold">
                      {selectedComplaint.complaint_code}
                    </h3>
                    <ComplaintStatusBadge status={selectedComplaint.status} />
                  </div>
                  <p className="text-xs text-slate-300">{t.complaints.drawer.title}</p>
                </div>
              </div>
              <button
                type="button"
                onClick={() => setSelectedId(null)}
                className="rounded-lg p-1.5 text-slate-400 hover:bg-slate-800 hover:text-white"
              >
                <X className="h-5 w-5" />
              </button>
            </div>

            {/* Body */}
            <div className="flex-1 space-y-5 overflow-y-auto p-6">
              {/* Parties & Linked Trip */}
              <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
                <div className="rounded-xl border border-slate-200 bg-slate-50 p-3.5">
                  <p className="text-[11px] font-bold text-slate-500">
                    {t.complaints.drawer.reporter}
                  </p>
                  <div className="mt-1 flex items-center gap-2">
                    <span className="text-sm font-extrabold text-slate-900">
                      {selectedComplaint.reporter_name}
                    </span>
                    <RoleBadge role={selectedComplaint.reporter_role} />
                  </div>
                  <p className="mt-0.5 font-mono text-xs text-slate-500" dir="ltr">
                    {selectedComplaint.reporter_phone || '—'}
                  </p>
                </div>

                <div className="rounded-xl border border-slate-200 bg-slate-50 p-3.5">
                  <p className="text-[11px] font-bold text-slate-500">
                    {t.complaints.drawer.reportedUser}
                  </p>
                  {selectedComplaint.reported_user_name ? (
                    <div className="mt-1 flex items-center gap-2">
                      <span className="text-sm font-extrabold text-slate-900">
                        {selectedComplaint.reported_user_name}
                      </span>
                      {selectedComplaint.reported_user_role && (
                        <RoleBadge role={selectedComplaint.reported_user_role} />
                      )}
                    </div>
                  ) : (
                    <p className="mt-1 text-sm text-slate-400">{t.common.none}</p>
                  )}
                  {selectedComplaint.request_code && (
                    <p className="mt-1 text-xs font-bold text-amber-700">
                      {t.complaints.drawer.linkedTrip}: {selectedComplaint.request_code}
                    </p>
                  )}
                </div>
              </div>

              {/* Complaint Description */}
              <div className="rounded-2xl border border-slate-200 bg-white p-4">
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <span className="rounded-md bg-amber-50 px-2.5 py-0.5 text-xs font-bold text-amber-800">
                    {t.complaints.categories[selectedComplaint.category]}
                  </span>
                  <span className="text-xs text-slate-400">
                    {formatDateTime(selectedComplaint.created_at, locale)}
                  </span>
                </div>
                <h4 className="mt-2.5 text-base font-extrabold text-slate-900">
                  {selectedComplaint.subject}
                </h4>
                <p className="mt-2 whitespace-pre-wrap text-sm leading-relaxed text-slate-700">
                  {selectedComplaint.description}
                </p>
              </div>

              {/* Evidence Photos/Files from private complaint-evidence bucket */}
              <div>
                <h4 className="text-sm font-extrabold text-slate-900">
                  {t.complaints.drawer.evidence} ({selectedComplaint.evidence_paths?.length ?? 0})
                </h4>
                {!selectedComplaint.evidence_paths ||
                selectedComplaint.evidence_paths.length === 0 ? (
                  <p className="mt-2 rounded-xl border border-dashed border-slate-300 p-4 text-center text-xs text-slate-500">
                    {t.complaints.drawer.noEvidence}
                  </p>
                ) : loadingEvidence ? (
                  <p className="mt-2 text-xs text-slate-500">{t.common.loading}</p>
                ) : (
                  <div className="mt-3 grid grid-cols-1 gap-3 sm:grid-cols-2">
                    {evidenceUrls.map((ev, idx) => {
                      const pdf = isPdfPath(ev.path);
                      return (
                        <div
                          key={`${ev.path}-${idx}`}
                          className="overflow-hidden rounded-xl border border-slate-200 bg-slate-50"
                        >
                          {!ev.url ? (
                            <div className="flex h-40 items-center justify-center p-4 text-xs text-slate-400">
                              {t.drivers.drawer.previewFailed}
                            </div>
                          ) : pdf ? (
                            <a
                              href={ev.url}
                              target="_blank"
                              rel="noreferrer"
                              className="flex h-40 flex-col items-center justify-center gap-2 text-slate-700 hover:text-amber-600"
                            >
                              <FileText className="h-8 w-8 text-amber-500" />
                              <span className="text-xs font-bold">{t.common.pdfDocument}</span>
                              <span className="inline-flex items-center gap-1 text-[11px] text-amber-600">
                                <ExternalLink className="h-3 w-3" />
                                {t.common.openInNewTab}
                              </span>
                            </a>
                          ) : (
                            <a
                              href={ev.url}
                              target="_blank"
                              rel="noreferrer"
                              className="group relative block h-44 w-full"
                            >
                              <img
                                src={ev.url}
                                alt={`Evidence ${idx + 1}`}
                                className="h-full w-full object-cover transition duration-300 group-hover:scale-105"
                              />
                              <span className="absolute top-2 end-2 rounded-lg bg-slate-900/75 p-1.5 text-white opacity-0 transition group-hover:opacity-100">
                                <ExternalLink className="h-3.5 w-3.5" />
                              </span>
                            </a>
                          )}
                        </div>
                      );
                    })}
                  </div>
                )}
              </div>

              {/* Resolution Form */}
              <div className="rounded-2xl border border-slate-200 bg-slate-50/80 p-4 space-y-4">
                <h4 className="text-sm font-extrabold text-slate-900">
                  {t.complaints.drawer.resolutionSection}
                </h4>

                <div>
                  <label className="mb-1.5 block text-xs font-bold text-slate-700">
                    {t.complaints.drawer.statusLabel}
                  </label>
                  <select
                    value={nextStatus}
                    onChange={(e) => setNextStatus(e.target.value as ComplaintStatus)}
                    className="w-full rounded-xl border border-slate-300 bg-white px-3.5 py-2.5 text-sm font-bold text-slate-900 focus:border-amber-500 focus:outline-none focus:ring-2 focus:ring-amber-500/20"
                  >
                    <option value="open">{t.statuses.complaint.open}</option>
                    <option value="in_progress">{t.statuses.complaint.in_progress}</option>
                    <option value="resolved">{t.statuses.complaint.resolved}</option>
                    <option value="dismissed">{t.statuses.complaint.dismissed}</option>
                  </select>
                </div>

                <div>
                  <label className="mb-1.5 block text-xs font-bold text-slate-700">
                    {t.complaints.drawer.adminNotesLabel}
                  </label>
                  <textarea
                    rows={4}
                    value={adminNotes}
                    onChange={(e) => setAdminNotes(e.target.value)}
                    placeholder={t.complaints.drawer.adminNotesPlaceholder}
                    className="w-full rounded-xl border border-slate-300 bg-white px-3.5 py-2.5 text-sm text-slate-900 focus:border-amber-500 focus:outline-none focus:ring-2 focus:ring-amber-500/20"
                  />
                </div>

                {selectedComplaint.resolved_at && (
                  <p className="text-xs text-slate-500">
                    {t.complaints.drawer.resolvedAt}:{' '}
                    <span className="font-bold text-slate-700">
                      {formatDateTime(selectedComplaint.resolved_at, locale)}
                    </span>
                  </p>
                )}

                <button
                  type="button"
                  disabled={saving}
                  onClick={() => void handleResolve()}
                  className="inline-flex w-full items-center justify-center gap-2 rounded-xl bg-amber-500 px-4 py-2.5 text-sm font-extrabold text-slate-950 shadow-xs transition hover:bg-amber-400 disabled:opacity-60"
                >
                  <CheckCircle2 className="h-4 w-4" />
                  <span>{saving ? t.common.saving : t.complaints.drawer.saveResolution}</span>
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
