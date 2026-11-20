import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  Search,
  RefreshCw,
  MapPin,
  Flag,
  User,
  Truck,
  Ban,
  Crosshair,
  Clock,
  CreditCard,
  Navigation,
} from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useLanguage } from '../i18n/LanguageContext';
import { useToast } from '../components/Toast';
import { formatCurrency, formatDistance, formatRelativeTime } from '../lib/format';
import { TripStatusBadge } from '../components/StatusBadge';
import { LiveTripsMap } from '../components/LiveTripsMap';
import { ConfirmModal } from '../components/ConfirmModal';
import type { AdminActiveTrip, TripStatus } from '../types/database';

const ACTIVE_STATUSES: TripStatus[] = [
  'searching',
  'driver_assigned',
  'en_route_to_pickup',
  'arrived_at_pickup',
  'vehicle_loaded',
  'en_route_to_dropoff',
];

export function ActiveTripsPage() {
  const { locale, t } = useLanguage();
  const { showToast } = useToast();

  const [trips, setTrips] = useState<AdminActiveTrip[]>([]);
  const [loading, setLoading] = useState(true);
  const [statusFilter, setStatusFilter] = useState<'all' | TripStatus>('all');
  const [search, setSearch] = useState('');
  const [selectedTripId, setSelectedTripId] = useState<string | null>(null);
  const [cancelTarget, setCancelTarget] = useState<AdminActiveTrip | null>(null);
  const [cancelling, setCancelling] = useState(false);
  const debounceRef = useRef<number | null>(null);

  const fetchTrips = useCallback(
    async (silent = false) => {
      if (!silent) setLoading(true);
      const { data, error } = await supabase
        .from('v_admin_active_trips')
        .select('*')
        .order('created_at', { ascending: false });

      if (error) {
        showToast(error.message, 'error');
      } else {
        setTrips((data ?? []) as AdminActiveTrip[]);
      }
      setLoading(false);
    },
    [showToast]
  );

  useEffect(() => {
    void fetchTrips(false);

    const scheduleRefresh = () => {
      if (debounceRef.current) window.clearTimeout(debounceRef.current);
      debounceRef.current = window.setTimeout(() => {
        void fetchTrips(true);
      }, 350);
    };

    const channel = supabase
      .channel('admin-active-trips-realtime')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'rescue_requests' }, scheduleRefresh)
      .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'drivers' }, scheduleRefresh)
      .subscribe();

    return () => {
      if (debounceRef.current) window.clearTimeout(debounceRef.current);
      void supabase.removeChannel(channel);
    };
  }, [fetchTrips]);

  const filteredTrips = useMemo(() => {
    const q = search.trim().toLowerCase();
    return trips.filter((trip) => {
      if (statusFilter !== 'all' && trip.status !== statusFilter) return false;
      if (!q) return true;
      const haystack = [
        trip.request_code,
        trip.customer_name,
        trip.customer_phone,
        trip.driver_name,
        trip.driver_phone,
        trip.winch_plate_number,
        trip.pickup_address,
        trip.dropoff_address,
      ]
        .filter(Boolean)
        .join(' ')
        .toLowerCase();
      return haystack.includes(q);
    });
  }, [trips, statusFilter, search]);

  const searchingCount = useMemo(
    () => trips.filter((item) => item.status === 'searching').length,
    [trips]
  );

  const handleCancelTrip = async (reason: string) => {
    if (!cancelTarget) return;
    setCancelling(true);
    const { error } = await supabase.rpc('cancel_rescue_request', {
      p_request_id: cancelTarget.id,
      p_reason: reason,
    });
    setCancelling(false);

    if (error) {
      showToast(error.message, 'error');
      return;
    }

    showToast(t.trips.tripCancelledToast, 'success');
    if (selectedTripId === cancelTarget.id) setSelectedTripId(null);
    setCancelTarget(null);
    await fetchTrips(true);
  };

  return (
    <div className="space-y-5">
      {/* Header + Summary Counters */}
      <div className="flex flex-col justify-between gap-4 lg:flex-row lg:items-center">
        <div>
          <h2 className="text-xl font-extrabold text-slate-900">{t.trips.title}</h2>
          <p className="mt-0.5 text-sm text-slate-500">{t.trips.subtitle}</p>
        </div>

        <div className="flex flex-wrap items-center gap-2.5">
          <div className="rounded-xl border border-slate-200 bg-white px-3.5 py-2 text-xs font-bold text-slate-700">
            {t.trips.totalActive}:{' '}
            <span className="text-slate-950">{trips.length}</span>
          </div>
          <div className="rounded-xl border border-amber-200 bg-amber-50 px-3.5 py-2 text-xs font-bold text-amber-800">
            {t.trips.searchingCount}: <span>{searchingCount}</span>
          </div>
          <div className="rounded-xl border border-emerald-200 bg-emerald-50 px-3.5 py-2 text-xs font-bold text-emerald-800">
            {t.trips.inProgressCount}: <span>{trips.length - searchingCount}</span>
          </div>
          <button
            type="button"
            onClick={() => void fetchTrips(false)}
            className="inline-flex items-center gap-1.5 rounded-xl border border-slate-200 bg-white px-3.5 py-2 text-xs font-bold text-slate-700 hover:bg-slate-50"
          >
            <RefreshCw className={`h-4 w-4 ${loading ? 'animate-spin' : ''}`} />
            <span>{t.common.refresh}</span>
          </button>
        </div>
      </div>

      {/* Filter & Search Toolbar */}
      <div className="flex flex-col gap-3 rounded-2xl border border-slate-200 bg-white p-4 shadow-2xs md:flex-row md:items-center">
        <div className="relative flex-1">
          <Search className="pointer-events-none absolute top-1/2 start-3.5 h-4 w-4 -translate-y-1/2 text-slate-400" />
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder={t.trips.searchPlaceholder}
            className="w-full rounded-xl border border-slate-200 bg-slate-50/60 py-2 ps-10 pe-4 text-sm text-slate-900 focus:border-amber-500 focus:bg-white focus:outline-none focus:ring-2 focus:ring-amber-500/20"
          />
        </div>
        <select
          value={statusFilter}
          onChange={(e) => setStatusFilter(e.target.value as 'all' | TripStatus)}
          className="rounded-xl border border-slate-200 bg-slate-50/60 px-3.5 py-2 text-xs font-bold text-slate-700 focus:border-amber-500 focus:bg-white focus:outline-none"
        >
          <option value="all">{t.trips.allStatuses}</option>
          {ACTIVE_STATUSES.map((st) => (
            <option key={st} value={st}>
              {t.statuses.trip[st]}
            </option>
          ))}
        </select>
      </div>

      {/* Main Split View: Live Map + Active Trip Feed */}
      <div className="grid grid-cols-1 gap-5 xl:grid-cols-12">
        {/* Interactive Leaflet Map */}
        <div className="xl:col-span-7">
          <LiveTripsMap
            trips={filteredTrips}
            selectedTripId={selectedTripId}
            onSelectTrip={(id) => setSelectedTripId(id)}
          />
        </div>

        {/* Active Trips Cards Feed */}
        <div className="flex flex-col rounded-2xl border border-slate-200 bg-white shadow-2xs xl:col-span-5 xl:h-[620px]">
          <div className="flex items-center justify-between border-b border-slate-100 px-4 py-3">
            <div className="flex items-center gap-2">
              <Navigation className="h-4 w-4 text-amber-500" />
              <span className="text-sm font-extrabold text-slate-900">
                {t.trips.totalActive} ({filteredTrips.length})
              </span>
            </div>
          </div>

          <div className="flex-1 space-y-3 overflow-y-auto p-4">
            {loading ? (
              <p className="py-12 text-center text-sm text-slate-500">{t.common.loading}</p>
            ) : filteredTrips.length === 0 ? (
              <div className="flex flex-col items-center justify-center py-14 text-center">
                <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-slate-100 text-slate-400">
                  <Navigation className="h-6 w-6" />
                </div>
                <p className="mt-3 text-sm font-bold text-slate-800">{t.trips.noActiveTrips}</p>
                <p className="mt-1 max-w-xs text-xs text-slate-500">
                  {t.trips.noActiveTripsDesc}
                </p>
              </div>
            ) : (
              filteredTrips.map((trip) => {
                const isSelected = trip.id === selectedTripId;
                const winchName = locale === 'ar' ? trip.winch_type_ar : trip.winch_type_en;

                return (
                  <div
                    key={trip.id}
                    onClick={() => setSelectedTripId(trip.id)}
                    className={`cursor-pointer rounded-2xl border p-4 transition ${
                      isSelected
                        ? 'border-amber-500 bg-amber-50/40 ring-2 ring-amber-400/30'
                        : 'border-slate-200 bg-white hover:border-amber-300 hover:bg-slate-50/60'
                    }`}
                  >
                    {/* Card Header */}
                    <div className="flex flex-wrap items-center justify-between gap-2">
                      <div className="flex items-center gap-2">
                        <span className="font-mono text-sm font-extrabold text-slate-900">
                          {trip.request_code}
                        </span>
                        <span className="rounded-md bg-slate-100 px-2 py-0.5 text-[11px] font-bold text-slate-600">
                          {winchName}
                        </span>
                      </div>
                      <TripStatusBadge status={trip.status} />
                    </div>

                    {/* Addresses */}
                    <div className="mt-3 space-y-1.5 text-xs">
                      <div className="flex items-start gap-2 text-slate-700">
                        <MapPin className="mt-0.5 h-3.5 w-3.5 shrink-0 text-amber-500" />
                        <span className="line-clamp-1 font-medium">{trip.pickup_address}</span>
                      </div>
                      <div className="flex items-start gap-2 text-slate-700">
                        <Flag className="mt-0.5 h-3.5 w-3.5 shrink-0 text-emerald-500" />
                        <span className="line-clamp-1 font-medium">{trip.dropoff_address}</span>
                      </div>
                    </div>

                    {/* Customer & Driver */}
                    <div className="mt-3 grid grid-cols-2 gap-2 rounded-xl bg-slate-50 p-2.5 text-xs">
                      <div className="min-w-0">
                        <span className="flex items-center gap-1 text-[10px] font-bold text-slate-400">
                          <User className="h-3 w-3" />
                          {t.trips.customer}
                        </span>
                        <p className="mt-0.5 truncate font-bold text-slate-800">
                          {trip.customer_name}
                        </p>
                        <p className="truncate font-mono text-[11px] text-slate-500" dir="ltr">
                          {trip.customer_phone || '—'}
                        </p>
                      </div>
                      <div className="min-w-0">
                        <span className="flex items-center gap-1 text-[10px] font-bold text-slate-400">
                          <Truck className="h-3 w-3" />
                          {t.trips.driver}
                        </span>
                        {trip.driver_name ? (
                          <>
                            <p className="mt-0.5 truncate font-bold text-slate-800">
                              {trip.driver_name}
                            </p>
                            <p className="truncate font-mono text-[11px] text-slate-500">
                              {trip.winch_plate_number || trip.driver_phone || '—'}
                            </p>
                          </>
                        ) : (
                          <p className="mt-0.5 text-[11px] font-semibold text-amber-600">
                            {t.trips.unassigned}
                          </p>
                        )}
                      </div>
                    </div>

                    {/* Metrics & Actions */}
                    <div className="mt-3 flex flex-wrap items-center justify-between gap-2 border-t border-slate-100 pt-2.5">
                      <div className="flex flex-wrap items-center gap-3 text-xs">
                        <span className="font-extrabold text-slate-900">
                          {formatCurrency(trip.final_price ?? trip.estimated_price, locale)}
                        </span>
                        <span className="text-slate-500">
                          {formatDistance(trip.estimated_distance_km, locale)}
                        </span>
                        <span className="inline-flex items-center gap-1 text-slate-500">
                          <CreditCard className="h-3.5 w-3.5" />
                          {t.trips.paymentMethods[trip.payment_method]}
                        </span>
                        <span className="inline-flex items-center gap-1 text-slate-400">
                          <Clock className="h-3 w-3" />
                          {formatRelativeTime(trip.created_at, locale)}
                        </span>
                      </div>

                      <div className="flex items-center gap-1.5">
                        <button
                          type="button"
                          onClick={(e) => {
                            e.stopPropagation();
                            setSelectedTripId(trip.id);
                          }}
                          className="inline-flex items-center gap-1 rounded-lg border border-slate-200 bg-white px-2.5 py-1 text-[11px] font-bold text-slate-700 hover:border-amber-400 hover:bg-amber-50"
                        >
                          <Crosshair className="h-3 w-3 text-amber-600" />
                          <span>{t.trips.focusOnMap}</span>
                        </button>
                        <button
                          type="button"
                          onClick={(e) => {
                            e.stopPropagation();
                            setCancelTarget(trip);
                          }}
                          className="inline-flex items-center gap-1 rounded-lg border border-red-200 bg-red-50 px-2.5 py-1 text-[11px] font-bold text-red-700 hover:bg-red-100"
                        >
                          <Ban className="h-3 w-3" />
                          <span>{t.common.cancel}</span>
                        </button>
                      </div>
                    </div>
                  </div>
                );
              })
            )}
          </div>
        </div>
      </div>

      {/* Tabular Summary View for Wide Operations Screens */}
      {filteredTrips.length > 0 && (
        <div className="overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-2xs">
          <div className="overflow-x-auto">
            <table className="w-full text-start text-xs">
              <thead className="border-b border-slate-200 bg-slate-50 font-bold text-slate-600">
                <tr>
                  <th className="px-4 py-3 text-start">#</th>
                  <th className="px-4 py-3 text-start">{t.drivers.table.status}</th>
                  <th className="px-4 py-3 text-start">{t.trips.customer}</th>
                  <th className="px-4 py-3 text-start">{t.trips.driver}</th>
                  <th className="px-4 py-3 text-start">{t.trips.winch}</th>
                  <th className="px-4 py-3 text-start">{t.trips.fare}</th>
                  <th className="px-4 py-3 text-start">{t.trips.payment}</th>
                  <th className="px-4 py-3 text-end">{t.common.actions}</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {filteredTrips.map((trip) => (
                  <tr
                    key={`row-${trip.id}`}
                    onClick={() => setSelectedTripId(trip.id)}
                    className={`cursor-pointer transition ${
                      selectedTripId === trip.id ? 'bg-amber-50/60' : 'hover:bg-slate-50'
                    }`}
                  >
                    <td className="px-4 py-3 font-mono font-extrabold text-slate-900">
                      {trip.request_code}
                    </td>
                    <td className="px-4 py-3">
                      <TripStatusBadge status={trip.status} />
                    </td>
                    <td className="px-4 py-3">
                      <p className="font-bold text-slate-900">{trip.customer_name}</p>
                      <p className="font-mono text-slate-500" dir="ltr">
                        {trip.customer_phone || '—'}
                      </p>
                    </td>
                    <td className="px-4 py-3">
                      {trip.driver_name ? (
                        <>
                          <p className="font-bold text-slate-900">{trip.driver_name}</p>
                          <p className="font-mono text-slate-500" dir="ltr">
                            {trip.driver_phone || '—'}
                          </p>
                        </>
                      ) : (
                        <span className="font-semibold text-amber-600">{t.trips.unassigned}</span>
                      )}
                    </td>
                    <td className="px-4 py-3">
                      <p className="font-semibold text-slate-800">
                        {locale === 'ar' ? trip.winch_type_ar : trip.winch_type_en}
                      </p>
                      <p className="font-mono text-slate-500">{trip.winch_plate_number || '—'}</p>
                    </td>
                    <td className="px-4 py-3 font-extrabold text-slate-900">
                      {formatCurrency(trip.final_price ?? trip.estimated_price, locale)}
                    </td>
                    <td className="px-4 py-3 font-semibold text-slate-700">
                      {t.trips.paymentMethods[trip.payment_method]}
                    </td>
                    <td className="px-4 py-3 text-end">
                      <button
                        type="button"
                        onClick={(e) => {
                          e.stopPropagation();
                          setCancelTarget(trip);
                        }}
                        className="rounded-lg border border-red-200 bg-red-50 px-2.5 py-1 font-bold text-red-700 hover:bg-red-100"
                      >
                        {t.trips.cancelTrip}
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Admin Cancel Modal */}
      <ConfirmModal
        open={Boolean(cancelTarget)}
        title={`${t.trips.cancelModalTitle} (${cancelTarget?.request_code ?? ''})`}
        description={t.trips.cancelModalDesc}
        confirmLabel={t.trips.cancelTrip}
        requireReason
        loading={cancelling}
        onCancel={() => setCancelTarget(null)}
        onConfirm={handleCancelTrip}
      />
    </div>
  );
}
