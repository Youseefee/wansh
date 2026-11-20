import { useCallback, useEffect, useMemo, useState } from 'react';
import {
  Search,
  RefreshCw,
  Eye,
  X,
  Truck,
  FileText,
  CheckCircle2,
  XCircle,
  ExternalLink,
  ShieldCheck,
  Ban,
  Clock,
  Star,
  Phone,
  Mail,
} from 'lucide-react';
import { supabase, getPublicWinchPhotoUrl, getSignedPrivateUrl, isPdfPath } from '../lib/supabase';
import { useLanguage } from '../i18n/LanguageContext';
import { useToast } from '../components/Toast';
import { formatDate, formatDateTime } from '../lib/format';
import { DriverStatusBadge, DocumentStatusBadge, Badge } from '../components/StatusBadge';
import { ConfirmModal } from '../components/ConfirmModal';
import type {
  AdminDriverApplication,
  DriverApprovalStatus,
  DriverDocumentSummary,
} from '../types/database';

type FilterTab = 'all' | DriverApprovalStatus;

export function DriversPage() {
  const { locale, t } = useLanguage();
  const { showToast } = useToast();

  const [drivers, setDrivers] = useState<AdminDriverApplication[]>([]);
  const [loading, setLoading] = useState(true);
  const [statusFilter, setStatusFilter] = useState<FilterTab>('all');
  const [search, setSearch] = useState('');
  const [selectedDriverId, setSelectedDriverId] = useState<string | null>(null);

  // Signed URLs cache for currently open driver's private KYC documents
  const [docSignedUrls, setDocSignedUrls] = useState<Record<string, string | null>>({});
  const [loadingDocs, setLoadingDocs] = useState(false);

  // Action states
  const [verifyWinches, setVerifyWinches] = useState(true);
  const [busyAction, setBusyAction] = useState(false);

  // Reason modal state for rejecting a document or rejecting/suspending a driver
  const [modalAction, setModalAction] = useState<
    | { kind: 'reject_doc'; doc: DriverDocumentSummary }
    | { kind: 'reject_driver'; driver: AdminDriverApplication }
    | { kind: 'suspend_driver'; driver: AdminDriverApplication }
    | null
  >(null);

  const fetchDrivers = useCallback(async (silent = false) => {
    if (!silent) setLoading(true);
    const { data, error } = await supabase
      .from('v_admin_driver_applications')
      .select('*')
      .order('created_at', { ascending: false });

    if (error) {
      showToast(error.message, 'error');
    } else {
      setDrivers((data ?? []) as AdminDriverApplication[]);
    }
    setLoading(false);
  }, [showToast]);

  useEffect(() => {
    void fetchDrivers(false);

    const channel = supabase
      .channel('admin-drivers-realtime')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'drivers' }, () => {
        void fetchDrivers(true);
      })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'driver_documents' }, () => {
        void fetchDrivers(true);
      })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'driver_winches' }, () => {
        void fetchDrivers(true);
      })
      .subscribe();

    return () => {
      void supabase.removeChannel(channel);
    };
  }, [fetchDrivers]);

  const selectedDriver = useMemo(
    () => drivers.find((d) => d.driver_id === selectedDriverId) ?? null,
    [drivers, selectedDriverId]
  );

  // Load signed URLs for private KYC documents whenever a driver is opened or their docs change
  useEffect(() => {
    if (!selectedDriver) {
      setDocSignedUrls({});
      return;
    }

    let cancelled = false;
    async function resolveSignedUrls(docs: DriverDocumentSummary[]) {
      setLoadingDocs(true);
      const entries = await Promise.all(
        docs.map(async (doc) => {
          const url = await getSignedPrivateUrl('driver-documents', doc.storage_path, 3600);
          return [doc.document_id, url] as const;
        })
      );
      if (!cancelled) {
        setDocSignedUrls(Object.fromEntries(entries));
        setLoadingDocs(false);
      }
    }

    void resolveSignedUrls(selectedDriver.documents ?? []);
    return () => {
      cancelled = true;
    };
  }, [selectedDriver]);

  const counts = useMemo(() => {
    const map: Record<FilterTab, number> = {
      all: drivers.length,
      pending: 0,
      under_review: 0,
      approved: 0,
      rejected: 0,
      suspended: 0,
    };
    for (const d of drivers) {
      map[d.approval_status] = (map[d.approval_status] ?? 0) + 1;
    }
    return map;
  }, [drivers]);

  const filteredDrivers = useMemo(() => {
    const q = search.trim().toLowerCase();
    return drivers.filter((d) => {
      if (statusFilter !== 'all' && d.approval_status !== statusFilter) return false;
      if (!q) return true;
      const plates = (d.winches ?? []).map((w) => w.plate_number).join(' ');
      const haystack = [
        d.full_name,
        d.phone,
        d.email,
        d.national_id_number,
        d.license_number,
        plates,
      ]
        .filter(Boolean)
        .join(' ')
        .toLowerCase();
      return haystack.includes(q);
    });
  }, [drivers, statusFilter, search]);

  const handleReviewDocument = async (
    documentId: string,
    status: 'approved' | 'rejected',
    rejectionReason: string | null = null
  ) => {
    setBusyAction(true);
    const { error } = await supabase.rpc('admin_review_document', {
      p_document_id: documentId,
      p_status: status,
      p_rejection_reason: rejectionReason,
    });
    setBusyAction(false);

    if (error) {
      showToast(error.message, 'error');
      return;
    }
    showToast(
      status === 'approved'
        ? t.drivers.drawer.docApprovedToast
        : t.drivers.drawer.docRejectedToast,
      'success'
    );
    setModalAction(null);
    await fetchDrivers(true);
  };

  const handleReviewDriver = async (
    driverId: string,
    decision: DriverApprovalStatus,
    rejectionReason: string | null = null
  ) => {
    setBusyAction(true);
    const { error } = await supabase.rpc('admin_review_driver', {
      p_driver_id: driverId,
      p_decision: decision,
      p_rejection_reason: rejectionReason,
      p_verify_winches: decision === 'approved' ? verifyWinches : false,
    });
    setBusyAction(false);

    if (error) {
      showToast(error.message, 'error');
      return;
    }
    showToast(t.drivers.drawer.driverUpdatedToast, 'success');
    setModalAction(null);
    await fetchDrivers(true);
  };

  const filterTabs: FilterTab[] = [
    'pending',
    'under_review',
    'approved',
    'rejected',
    'suspended',
    'all',
  ];

  return (
    <div className="space-y-5">
      {/* Header */}
      <div className="flex flex-col justify-between gap-3 sm:flex-row sm:items-center">
        <div>
          <h2 className="text-xl font-extrabold text-slate-900">{t.drivers.title}</h2>
          <p className="mt-0.5 text-sm text-slate-500">{t.drivers.subtitle}</p>
        </div>
        <button
          type="button"
          onClick={() => void fetchDrivers(false)}
          className="inline-flex items-center gap-2 self-start rounded-xl border border-slate-200 bg-white px-3.5 py-2 text-xs font-bold text-slate-700 shadow-2xs hover:bg-slate-50"
        >
          <RefreshCw className={`h-4 w-4 ${loading ? 'animate-spin' : ''}`} />
          <span>{t.common.refresh}</span>
        </button>
      </div>

      {/* Filter Tabs + Search */}
      <div className="flex flex-col gap-3 rounded-2xl border border-slate-200 bg-white p-4 shadow-2xs">
        <div className="flex flex-wrap items-center gap-2">
          {filterTabs.map((tab) => {
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
                <span>{t.drivers.tabs[tab]}</span>
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
            placeholder={t.drivers.searchPlaceholder}
            className="w-full rounded-xl border border-slate-200 bg-slate-50/60 py-2.5 ps-10 pe-4 text-sm text-slate-900 focus:border-amber-500 focus:bg-white focus:outline-none focus:ring-2 focus:ring-amber-500/20"
          />
        </div>
      </div>

      {/* Drivers Table */}
      <div className="overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-2xs">
        <div className="overflow-x-auto">
          <table className="w-full text-start text-sm">
            <thead className="border-b border-slate-200 bg-slate-50 text-xs font-bold text-slate-600">
              <tr>
                <th className="px-4 py-3.5 text-start">{t.drivers.table.driver}</th>
                <th className="px-4 py-3.5 text-start">{t.drivers.table.identity}</th>
                <th className="px-4 py-3.5 text-start">{t.drivers.table.winches}</th>
                <th className="px-4 py-3.5 text-start">{t.drivers.table.documents}</th>
                <th className="px-4 py-3.5 text-start">{t.drivers.table.status}</th>
                <th className="px-4 py-3.5 text-start">{t.drivers.table.performance}</th>
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
              ) : filteredDrivers.length === 0 ? (
                <tr>
                  <td colSpan={7} className="px-4 py-12 text-center text-sm text-slate-500">
                    {t.common.noData}
                  </td>
                </tr>
              ) : (
                filteredDrivers.map((driver) => {
                  const docs = driver.documents ?? [];
                  const approvedDocs = docs.filter((doc) => doc.review_status === 'approved').length;
                  const winches = driver.winches ?? [];

                  return (
                    <tr
                      key={driver.driver_id}
                      className="transition hover:bg-amber-50/30"
                    >
                      <td className="px-4 py-3.5">
                        <div className="flex items-center gap-3">
                          <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-slate-900 text-sm font-bold text-amber-400">
                            {(driver.full_name || 'D').slice(0, 1).toUpperCase()}
                          </div>
                          <div className="min-w-0">
                            <p className="font-bold text-slate-900">
                              {driver.full_name || '—'}
                            </p>
                            <p className="text-xs text-slate-500" dir="ltr">
                              {driver.phone || driver.email || '—'}
                            </p>
                          </div>
                        </div>
                      </td>
                      <td className="px-4 py-3.5">
                        <p className="font-mono text-xs font-semibold text-slate-800">
                          {driver.national_id_number || '—'}
                        </p>
                        <p className="text-xs text-slate-500">
                          {driver.license_number ? `#${driver.license_number}` : '—'}
                        </p>
                      </td>
                      <td className="px-4 py-3.5">
                        {winches.length === 0 ? (
                          <span className="text-xs text-slate-400">{t.common.none}</span>
                        ) : (
                          <div className="space-y-1">
                            {winches.slice(0, 2).map((w) => (
                              <div key={w.winch_id} className="flex items-center gap-1.5 text-xs">
                                <span className="font-semibold text-slate-800">
                                  {w.plate_number}
                                </span>
                                <span className="text-slate-500">
                                  ({locale === 'ar' ? w.winch_type_ar : w.winch_type_en})
                                </span>
                              </div>
                            ))}
                          </div>
                        )}
                      </td>
                      <td className="px-4 py-3.5">
                        <span className="inline-flex items-center gap-1.5 rounded-lg bg-slate-100 px-2.5 py-1 text-xs font-bold text-slate-700">
                          <FileText className="h-3.5 w-3.5 text-amber-600" />
                          {approvedDocs} / {docs.length}
                        </span>
                      </td>
                      <td className="px-4 py-3.5">
                        <div className="flex flex-col items-start gap-1">
                          <DriverStatusBadge status={driver.approval_status} />
                          {driver.is_online && (
                            <span className="inline-flex items-center gap-1 text-[11px] font-semibold text-emerald-600">
                              <span className="h-1.5 w-1.5 rounded-full bg-emerald-500" />
                              {t.common.online}
                            </span>
                          )}
                        </div>
                      </td>
                      <td className="px-4 py-3.5">
                        <div className="flex items-center gap-1 text-xs font-bold text-slate-800">
                          <Star className="h-3.5 w-3.5 fill-amber-400 text-amber-400" />
                          <span>{Number(driver.avg_rating ?? 5).toFixed(2)}</span>
                          <span className="text-slate-400">({driver.total_trips})</span>
                        </div>
                        <p className="text-[11px] text-slate-400">
                          {formatDate(driver.created_at, locale)}
                        </p>
                      </td>
                      <td className="px-4 py-3.5 text-end">
                        <button
                          type="button"
                          onClick={() => {
                            setVerifyWinches(true);
                            setSelectedDriverId(driver.driver_id);
                          }}
                          className="inline-flex items-center gap-1.5 rounded-xl bg-slate-900 px-3 py-1.5 text-xs font-bold text-white transition hover:bg-amber-500 hover:text-slate-950"
                        >
                          <Eye className="h-3.5 w-3.5" />
                          <span>{t.common.details}</span>
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

      {/* Driver KYC Review Slide-over Drawer */}
      {selectedDriver && (
        <div className="fixed inset-0 z-40 flex justify-end bg-slate-950/55 backdrop-blur-xs">
          <div
            className="fixed inset-0"
            onClick={() => setSelectedDriverId(null)}
          />
          <div className="relative z-10 flex h-full w-full max-w-3xl flex-col bg-white shadow-2xl">
            {/* Drawer Header */}
            <div className="flex items-center justify-between border-b border-slate-200 bg-[#0F172A] px-6 py-4 text-white">
              <div className="flex items-center gap-3">
                <div className="flex h-11 w-11 items-center justify-center rounded-xl bg-amber-500 font-extrabold text-slate-950">
                  {(selectedDriver.full_name || 'D').slice(0, 1).toUpperCase()}
                </div>
                <div>
                  <h3 className="text-base font-extrabold">{selectedDriver.full_name}</h3>
                  <p className="text-xs text-slate-300">{t.drivers.drawer.title}</p>
                </div>
              </div>
              <div className="flex items-center gap-3">
                <DriverStatusBadge status={selectedDriver.approval_status} />
                <button
                  type="button"
                  onClick={() => setSelectedDriverId(null)}
                  className="rounded-lg p-1.5 text-slate-400 hover:bg-slate-800 hover:text-white"
                >
                  <X className="h-5 w-5" />
                </button>
              </div>
            </div>

            {/* Drawer Scroll Body */}
            <div className="flex-1 space-y-6 overflow-y-auto p-6">
              {/* Profile Details Card */}
              <section className="rounded-2xl border border-slate-200 bg-slate-50/70 p-4">
                <h4 className="text-xs font-extrabold uppercase tracking-wider text-slate-500">
                  {t.drivers.drawer.profileSection}
                </h4>
                <div className="mt-3 grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3">
                  <div className="rounded-xl bg-white p-3 border border-slate-200/70">
                    <span className="flex items-center gap-1.5 text-[11px] font-semibold text-slate-500">
                      <Phone className="h-3.5 w-3.5" />
                      {t.users.table.contact}
                    </span>
                    <p className="mt-1 font-mono text-sm font-bold text-slate-900" dir="ltr">
                      {selectedDriver.phone || '—'}
                    </p>
                  </div>
                  <div className="rounded-xl bg-white p-3 border border-slate-200/70">
                    <span className="flex items-center gap-1.5 text-[11px] font-semibold text-slate-500">
                      <Mail className="h-3.5 w-3.5" />
                      {t.auth.email}
                    </span>
                    <p className="mt-1 truncate text-sm font-bold text-slate-900" dir="ltr">
                      {selectedDriver.email || '—'}
                    </p>
                  </div>
                  <div className="rounded-xl bg-white p-3 border border-slate-200/70">
                    <span className="text-[11px] font-semibold text-slate-500">
                      {t.drivers.drawer.nationalId}
                    </span>
                    <p className="mt-1 font-mono text-sm font-bold text-slate-900">
                      {selectedDriver.national_id_number || '—'}
                    </p>
                  </div>
                  <div className="rounded-xl bg-white p-3 border border-slate-200/70">
                    <span className="text-[11px] font-semibold text-slate-500">
                      {t.drivers.drawer.licenseNumber}
                    </span>
                    <p className="mt-1 font-mono text-sm font-bold text-slate-900">
                      {selectedDriver.license_number || '—'}
                    </p>
                  </div>
                  <div className="rounded-xl bg-white p-3 border border-slate-200/70">
                    <span className="text-[11px] font-semibold text-slate-500">
                      {t.drivers.drawer.licenseExpiry}
                    </span>
                    <p className="mt-1 text-sm font-bold text-slate-900">
                      {formatDate(selectedDriver.license_expiry, locale)}
                    </p>
                  </div>
                  <div className="rounded-xl bg-white p-3 border border-slate-200/70">
                    <span className="text-[11px] font-semibold text-slate-500">
                      {t.drivers.table.joined}
                    </span>
                    <p className="mt-1 text-sm font-bold text-slate-900">
                      {formatDateTime(selectedDriver.created_at, locale)}
                    </p>
                  </div>
                </div>

                {selectedDriver.rejection_reason && (
                  <div className="mt-3 rounded-xl border border-red-200 bg-red-50 p-3 text-xs text-red-800">
                    <span className="font-bold">{t.drivers.drawer.rejectionReason}: </span>
                    <span>{selectedDriver.rejection_reason}</span>
                  </div>
                )}
              </section>

              {/* Registered Winches + Public winch-photos */}
              <section>
                <div className="flex items-center gap-2">
                  <Truck className="h-4 w-4 text-amber-600" />
                  <h4 className="text-sm font-extrabold text-slate-900">
                    {t.drivers.drawer.winchesSection} ({selectedDriver.winches?.length ?? 0})
                  </h4>
                </div>
                {!selectedDriver.winches || selectedDriver.winches.length === 0 ? (
                  <p className="mt-2 rounded-xl border border-dashed border-slate-300 p-4 text-center text-xs text-slate-500">
                    {t.drivers.drawer.noWinches}
                  </p>
                ) : (
                  <div className="mt-3 space-y-3">
                    {selectedDriver.winches.map((winch) => (
                      <div
                        key={winch.winch_id}
                        className="rounded-2xl border border-slate-200 bg-white p-4"
                      >
                        <div className="flex flex-wrap items-center justify-between gap-2">
                          <div>
                            <p className="text-sm font-extrabold text-slate-900">
                              {winch.brand} {winch.model} {winch.year ?? ''}
                            </p>
                            <p className="text-xs text-slate-500">
                              {locale === 'ar' ? winch.winch_type_ar : winch.winch_type_en} ·{' '}
                              {t.drivers.drawer.plate}:{' '}
                              <span className="font-bold text-slate-800">{winch.plate_number}</span>
                            </p>
                          </div>
                          <div className="flex items-center gap-2">
                            <Badge
                              label={winch.is_verified ? t.common.verified : t.common.unverified}
                              tone={winch.is_verified ? 'emerald' : 'amber'}
                              dot
                            />
                            <Badge
                              label={winch.is_active ? t.common.active : t.common.inactive}
                              tone={winch.is_active ? 'blue' : 'slate'}
                            />
                          </div>
                        </div>

                        {winch.photo_paths && winch.photo_paths.length > 0 && (
                          <div className="mt-3">
                            <p className="mb-2 text-[11px] font-bold text-slate-500">
                              {t.drivers.drawer.winchPhotos}
                            </p>
                            <div className="grid grid-cols-2 gap-2.5 sm:grid-cols-3">
                              {winch.photo_paths.map((path, idx) => {
                                const publicUrl = getPublicWinchPhotoUrl(path);
                                return (
                                  <a
                                    key={`${winch.winch_id}-photo-${idx}`}
                                    href={publicUrl}
                                    target="_blank"
                                    rel="noreferrer"
                                    className="group relative block aspect-video overflow-hidden rounded-xl border border-slate-200 bg-slate-100"
                                  >
                                    <img
                                      src={publicUrl}
                                      alt={winch.plate_number}
                                      className="h-full w-full object-cover transition duration-300 group-hover:scale-105"
                                    />
                                  </a>
                                );
                              })}
                            </div>
                          </div>
                        )}
                      </div>
                    ))}
                  </div>
                )}
              </section>

              {/* Private KYC Documents (driver-documents bucket signed URLs) */}
              <section>
                <div className="flex items-center gap-2">
                  <FileText className="h-4 w-4 text-amber-600" />
                  <h4 className="text-sm font-extrabold text-slate-900">
                    {t.drivers.drawer.documentsSection} ({selectedDriver.documents?.length ?? 0})
                  </h4>
                </div>

                {!selectedDriver.documents || selectedDriver.documents.length === 0 ? (
                  <p className="mt-2 rounded-xl border border-dashed border-slate-300 p-4 text-center text-xs text-slate-500">
                    {t.drivers.drawer.noDocuments}
                  </p>
                ) : (
                  <div className="mt-3 grid grid-cols-1 gap-4 sm:grid-cols-2">
                    {selectedDriver.documents.map((doc) => {
                      const signedUrl = docSignedUrls[doc.document_id];
                      const pdf = isPdfPath(doc.storage_path);

                      return (
                        <div
                          key={doc.document_id}
                          className="flex flex-col justify-between overflow-hidden rounded-2xl border border-slate-200 bg-white"
                        >
                          {/* Document Preview */}
                          <div className="relative flex h-44 items-center justify-center bg-slate-100">
                            {loadingDocs && signedUrl === undefined ? (
                              <span className="text-xs font-medium text-slate-500">
                                {t.drivers.drawer.loadingPreview}
                              </span>
                            ) : !signedUrl ? (
                              <span className="px-4 text-center text-xs font-medium text-slate-400">
                                {t.drivers.drawer.previewFailed}
                              </span>
                            ) : pdf ? (
                              <a
                                href={signedUrl}
                                target="_blank"
                                rel="noreferrer"
                                className="flex flex-col items-center gap-2 rounded-xl bg-white px-5 py-4 text-slate-700 shadow-xs transition hover:text-amber-600"
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
                                href={signedUrl}
                                target="_blank"
                                rel="noreferrer"
                                className="group block h-full w-full"
                              >
                                <img
                                  src={signedUrl}
                                  alt={t.drivers.docTypes[doc.document_type]}
                                  className="h-full w-full object-cover transition duration-300 group-hover:scale-105"
                                />
                                <span className="absolute top-2 end-2 rounded-lg bg-slate-900/75 p-1.5 text-white opacity-0 transition group-hover:opacity-100">
                                  <ExternalLink className="h-3.5 w-3.5" />
                                </span>
                              </a>
                            )}
                          </div>

                          {/* Document Info & Per-Document Actions */}
                          <div className="space-y-3 p-3.5">
                            <div className="flex items-start justify-between gap-2">
                              <div>
                                <p className="text-xs font-extrabold text-slate-900">
                                  {t.drivers.docTypes[doc.document_type]}
                                </p>
                                {doc.expires_at && (
                                  <p className="mt-0.5 text-[11px] text-slate-500">
                                    {t.drivers.drawer.expiresAt}: {formatDate(doc.expires_at, locale)}
                                  </p>
                                )}
                              </div>
                              <DocumentStatusBadge status={doc.review_status} />
                            </div>

                            {doc.rejection_reason && (
                              <p className="rounded-lg bg-red-50 px-2.5 py-1.5 text-[11px] font-medium text-red-700">
                                {doc.rejection_reason}
                              </p>
                            )}

                            <div className="flex items-center gap-2 pt-1">
                              <button
                                type="button"
                                disabled={busyAction || doc.review_status === 'approved'}
                                onClick={() => void handleReviewDocument(doc.document_id, 'approved')}
                                className="flex flex-1 items-center justify-center gap-1 rounded-xl bg-emerald-600 px-2.5 py-1.5 text-xs font-bold text-white transition hover:bg-emerald-700 disabled:opacity-45"
                              >
                                <CheckCircle2 className="h-3.5 w-3.5" />
                                <span>{t.drivers.drawer.approveDoc}</span>
                              </button>
                              <button
                                type="button"
                                disabled={busyAction}
                                onClick={() => setModalAction({ kind: 'reject_doc', doc })}
                                className="flex flex-1 items-center justify-center gap-1 rounded-xl border border-red-200 bg-red-50 px-2.5 py-1.5 text-xs font-bold text-red-700 transition hover:bg-red-100 disabled:opacity-45"
                              >
                                <XCircle className="h-3.5 w-3.5" />
                                <span>{t.drivers.drawer.rejectDoc}</span>
                              </button>
                            </div>
                          </div>
                        </div>
                      );
                    })}
                  </div>
                )}
              </section>
            </div>

            {/* Sticky Drawer Decision Footer */}
            <div className="border-t border-slate-200 bg-slate-50 px-6 py-4">
              <div className="flex flex-col gap-3">
                <label className="flex cursor-pointer items-center gap-2 text-xs font-semibold text-slate-700">
                  <input
                    type="checkbox"
                    checked={verifyWinches}
                    onChange={(e) => setVerifyWinches(e.target.checked)}
                    className="h-4 w-4 rounded border-slate-300 accent-amber-500"
                  />
                  <span>{t.drivers.drawer.verifyWinchesLabel}</span>
                </label>

                <div className="flex flex-wrap items-center gap-2">
                  <button
                    type="button"
                    disabled={busyAction}
                    onClick={() => void handleReviewDriver(selectedDriver.driver_id, 'approved')}
                    className="inline-flex items-center gap-1.5 rounded-xl bg-emerald-600 px-4 py-2 text-xs font-extrabold text-white shadow-xs transition hover:bg-emerald-700 disabled:opacity-50"
                  >
                    <ShieldCheck className="h-4 w-4" />
                    <span>{t.drivers.drawer.approveDriver}</span>
                  </button>

                  {selectedDriver.approval_status === 'pending' && (
                    <button
                      type="button"
                      disabled={busyAction}
                      onClick={() =>
                        void handleReviewDriver(selectedDriver.driver_id, 'under_review')
                      }
                      className="inline-flex items-center gap-1.5 rounded-xl border border-sky-200 bg-sky-50 px-3.5 py-2 text-xs font-bold text-sky-800 transition hover:bg-sky-100 disabled:opacity-50"
                    >
                      <Clock className="h-4 w-4" />
                      <span>{t.drivers.drawer.markUnderReview}</span>
                    </button>
                  )}

                  <button
                    type="button"
                    disabled={busyAction}
                    onClick={() =>
                      setModalAction({ kind: 'reject_driver', driver: selectedDriver })
                    }
                    className="inline-flex items-center gap-1.5 rounded-xl border border-red-200 bg-red-50 px-3.5 py-2 text-xs font-bold text-red-700 transition hover:bg-red-100 disabled:opacity-50"
                  >
                    <XCircle className="h-4 w-4" />
                    <span>{t.drivers.drawer.rejectDriver}</span>
                  </button>

                  <button
                    type="button"
                    disabled={busyAction}
                    onClick={() =>
                      setModalAction({ kind: 'suspend_driver', driver: selectedDriver })
                    }
                    className="inline-flex items-center gap-1.5 rounded-xl border border-slate-300 bg-white px-3.5 py-2 text-xs font-bold text-slate-700 transition hover:bg-slate-100 disabled:opacity-50"
                  >
                    <Ban className="h-4 w-4" />
                    <span>{t.drivers.drawer.suspendDriver}</span>
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Confirmation / Reason Modal */}
      <ConfirmModal
        open={Boolean(modalAction)}
        title={
          modalAction?.kind === 'reject_doc'
            ? t.drivers.drawer.rejectDocTitle
            : modalAction?.kind === 'reject_driver'
              ? t.drivers.drawer.rejectDriverTitle
              : t.drivers.drawer.suspendDriverTitle
        }
        description={
          modalAction?.kind === 'reject_doc'
            ? t.drivers.drawer.rejectDocDesc
            : modalAction?.kind === 'reject_driver'
              ? t.drivers.drawer.rejectDriverDesc
              : t.drivers.drawer.suspendDriverDesc
        }
        requireReason
        loading={busyAction}
        onCancel={() => setModalAction(null)}
        onConfirm={async (reason) => {
          if (!modalAction) return;
          if (modalAction.kind === 'reject_doc') {
            await handleReviewDocument(modalAction.doc.document_id, 'rejected', reason);
          } else if (modalAction.kind === 'reject_driver') {
            await handleReviewDriver(modalAction.driver.driver_id, 'rejected', reason);
          } else {
            await handleReviewDriver(modalAction.driver.driver_id, 'suspended', reason);
          }
        }}
      />
    </div>
  );
}
