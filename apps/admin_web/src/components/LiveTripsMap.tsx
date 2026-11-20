import { useEffect, useRef } from 'react';
import L from 'leaflet';
import { Maximize2 } from 'lucide-react';
import type { AdminActiveTrip } from '../types/database';
import { useLanguage } from '../i18n/LanguageContext';
import { formatCurrency } from '../lib/format';

interface LiveTripsMapProps {
  trips: AdminActiveTrip[];
  selectedTripId: string | null;
  onSelectTrip: (tripId: string) => void;
}

const DEFAULT_CENTER: [number, number] = [30.0444, 31.2357]; // Cairo

function escapeHtml(value: string | null | undefined): string {
  if (!value) return '';
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function createPinIcon(type: 'pickup' | 'dropoff' | 'driver', selected: boolean) {
  const size = selected ? 38 : 32;
  if (type === 'pickup') {
    return L.divIcon({
      className: 'wenshy-map-pin',
      html: `<div style="width:${size}px;height:${size}px;border-radius:9999px;background:#F59E0B;border:3px solid #0F172A;color:#0F172A;display:flex;align-items:center;justify-content:center;font-weight:800;font-size:13px;box-shadow:0 6px 14px rgba(15,23,42,0.3);transform:${selected ? 'scale(1.12)' : 'scale(1)'};">P</div>`,
      iconSize: [size, size],
      iconAnchor: [size / 2, size / 2],
    });
  }
  if (type === 'dropoff') {
    return L.divIcon({
      className: 'wenshy-map-pin',
      html: `<div style="width:${size}px;height:${size}px;border-radius:9999px;background:#10B981;border:3px solid #FFFFFF;color:#FFFFFF;display:flex;align-items:center;justify-content:center;font-weight:800;font-size:13px;box-shadow:0 6px 14px rgba(16,185,129,0.4);transform:${selected ? 'scale(1.12)' : 'scale(1)'};">D</div>`,
      iconSize: [size, size],
      iconAnchor: [size / 2, size / 2],
    });
  }
  return L.divIcon({
    className: 'wenshy-map-pin',
    html: `<div class="wenshy-truck-pulse" style="width:${size + 4}px;height:${size + 4}px;border-radius:9999px;background:#0F172A;border:3px solid #F59E0B;color:#F59E0B;display:flex;align-items:center;justify-content:center;box-shadow:0 8px 18px rgba(15,23,42,0.45);">
      <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M14 18V6a2 2 0 0 0-2-2H4a2 2 0 0 0-2 2v11a1 1 0 0 0 1 1h2"/><path d="M15 18H9"/><path d="M19 18h2a1 1 0 0 0 1-1v-3.65a1 1 0 0 0-.22-.624l-3.48-4.35A1 1 0 0 0 17.52 8H14"/><circle cx="17" cy="18" r="2"/><circle cx="7" cy="18" r="2"/></svg>
    </div>`,
    iconSize: [size + 4, size + 4],
    iconAnchor: [(size + 4) / 2, (size + 4) / 2],
  });
}

export function LiveTripsMap({ trips, selectedTripId, onSelectTrip }: LiveTripsMapProps) {
  const { locale, t } = useLanguage();
  const containerRef = useRef<HTMLDivElement | null>(null);
  const mapRef = useRef<L.Map | null>(null);
  const layerGroupRef = useRef<L.LayerGroup | null>(null);
  const hasAutoFittedRef = useRef(false);

  // Initialize Leaflet map once
  useEffect(() => {
    if (!containerRef.current || mapRef.current) return;

    const map = L.map(containerRef.current, {
      center: DEFAULT_CENTER,
      zoom: 11,
      zoomControl: true,
    });

    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: '&copy; OpenStreetMap contributors',
      maxZoom: 19,
    }).addTo(map);

    const group = L.layerGroup().addTo(map);
    mapRef.current = map;
    layerGroupRef.current = group;

    const resizeObserver = new ResizeObserver(() => {
      map.invalidateSize();
    });
    resizeObserver.observe(containerRef.current);

    return () => {
      resizeObserver.disconnect();
      map.remove();
      mapRef.current = null;
      layerGroupRef.current = null;
    };
  }, []);

  const fitAllTrips = () => {
    const map = mapRef.current;
    if (!map) return;

    const points: [number, number][] = [];
    for (const trip of trips) {
      points.push([trip.pickup_lat, trip.pickup_lng]);
      points.push([trip.dropoff_lat, trip.dropoff_lng]);
      if (trip.driver_lat !== null && trip.driver_lng !== null) {
        points.push([trip.driver_lat, trip.driver_lng]);
      }
    }
    if (points.length === 0) {
      map.setView(DEFAULT_CENTER, 11);
      return;
    }
    const bounds = L.latLngBounds(points);
    map.fitBounds(bounds, { padding: [48, 48], maxZoom: 15 });
  };

  // Render trip markers & routes
  useEffect(() => {
    const map = mapRef.current;
    const group = layerGroupRef.current;
    if (!map || !group) return;

    group.clearLayers();

    for (const trip of trips) {
      const isSelected = trip.id === selectedTripId;
      const statusLabel = t.statuses.trip[trip.status];
      const winchName = locale === 'ar' ? trip.winch_type_ar : trip.winch_type_en;
      const fareLabel = formatCurrency(trip.final_price ?? trip.estimated_price, locale);

      // Pickup -> Dropoff polyline
      L.polyline(
        [
          [trip.pickup_lat, trip.pickup_lng],
          [trip.dropoff_lat, trip.dropoff_lng],
        ],
        {
          color: isSelected ? '#F59E0B' : '#64748B',
          weight: isSelected ? 4 : 2.5,
          opacity: isSelected ? 0.95 : 0.45,
          dashArray: '8, 6',
        }
      ).addTo(group);

      // Pickup marker
      const pickupMarker = L.marker([trip.pickup_lat, trip.pickup_lng], {
        icon: createPinIcon('pickup', isSelected),
        zIndexOffset: isSelected ? 500 : 100,
      }).addTo(group);

      pickupMarker.bindPopup(
        `<div style="min-width:210px;font-size:12px;">
          <div style="font-weight:800;color:#0F172A;margin-bottom:4px;">${escapeHtml(trip.request_code)} · ${escapeHtml(t.trips.pickup)}</div>
          <div style="color:#475569;margin-bottom:4px;">${escapeHtml(trip.pickup_address)}</div>
          <div style="color:#0F172A;font-weight:600;">${escapeHtml(trip.customer_name)} · ${escapeHtml(fareLabel)}</div>
          <div style="color:#D97706;font-weight:600;margin-top:2px;">${escapeHtml(statusLabel)}</div>
        </div>`
      );
      pickupMarker.on('click', () => onSelectTrip(trip.id));

      // Dropoff marker
      const dropoffMarker = L.marker([trip.dropoff_lat, trip.dropoff_lng], {
        icon: createPinIcon('dropoff', isSelected),
        zIndexOffset: isSelected ? 450 : 90,
      }).addTo(group);

      dropoffMarker.bindPopup(
        `<div style="min-width:210px;font-size:12px;">
          <div style="font-weight:800;color:#0F172A;margin-bottom:4px;">${escapeHtml(trip.request_code)} · ${escapeHtml(t.trips.dropoff)}</div>
          <div style="color:#475569;margin-bottom:4px;">${escapeHtml(trip.dropoff_address)}</div>
          <div style="color:#10B981;font-weight:600;">${escapeHtml(winchName)}</div>
        </div>`
      );
      dropoffMarker.on('click', () => onSelectTrip(trip.id));

      // Live Driver truck marker
      if (trip.driver_lat !== null && trip.driver_lng !== null) {
        const targetCoord: [number, number] =
          trip.status === 'vehicle_loaded' || trip.status === 'en_route_to_dropoff'
            ? [trip.dropoff_lat, trip.dropoff_lng]
            : [trip.pickup_lat, trip.pickup_lng];

        L.polyline([[trip.driver_lat, trip.driver_lng], targetCoord], {
          color: '#0F172A',
          weight: isSelected ? 3.5 : 2,
          opacity: isSelected ? 0.9 : 0.4,
          dashArray: '4, 6',
        }).addTo(group);

        const driverMarker = L.marker([trip.driver_lat, trip.driver_lng], {
          icon: createPinIcon('driver', isSelected),
          zIndexOffset: isSelected ? 900 : 300,
        }).addTo(group);

        driverMarker.bindPopup(
          `<div style="min-width:210px;font-size:12px;">
            <div style="font-weight:800;color:#0F172A;margin-bottom:4px;">${escapeHtml(trip.driver_name || t.trips.driver)}</div>
            <div style="color:#475569;">${escapeHtml(trip.request_code)} · ${escapeHtml(trip.winch_plate_number || '—')}</div>
            <div style="color:#D97706;font-weight:700;margin-top:4px;">${escapeHtml(statusLabel)}</div>
          </div>`
        );
        driverMarker.on('click', () => onSelectTrip(trip.id));
      }
    }

    if (!hasAutoFittedRef.current && trips.length > 0) {
      hasAutoFittedRef.current = true;
      fitAllTrips();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [trips, selectedTripId, locale]);

  // Focus smoothly when selectedTripId changes
  useEffect(() => {
    const map = mapRef.current;
    if (!map || !selectedTripId) return;
    const trip = trips.find((item) => item.id === selectedTripId);
    if (!trip) return;

    const points: [number, number][] = [
      [trip.pickup_lat, trip.pickup_lng],
      [trip.dropoff_lat, trip.dropoff_lng],
    ];
    if (trip.driver_lat !== null && trip.driver_lng !== null) {
      points.push([trip.driver_lat, trip.driver_lng]);
    }
    const bounds = L.latLngBounds(points);
    map.fitBounds(bounds, { padding: [60, 60], maxZoom: 15, animate: true });
  }, [selectedTripId, trips]);

  return (
    <div className="relative h-[460px] w-full overflow-hidden rounded-2xl border border-slate-200 bg-slate-100 shadow-xs lg:h-[620px]">
      <div ref={containerRef} className="h-full w-full" />

      {/* Top Floating Controls */}
      <div className="pointer-events-none absolute top-3 end-3 z-[400] flex flex-wrap items-center gap-2">
        <button
          type="button"
          onClick={fitAllTrips}
          className="pointer-events-auto flex items-center gap-1.5 rounded-xl border border-slate-200 bg-white/95 px-3 py-1.5 text-xs font-bold text-slate-800 shadow-md backdrop-blur-xs transition hover:bg-amber-50 hover:border-amber-300"
        >
          <Maximize2 className="h-3.5 w-3.5 text-amber-600" />
          <span>{t.trips.fitAll}</span>
        </button>
      </div>

      {/* Map Legend */}
      <div className="pointer-events-none absolute bottom-3 start-3 z-[400] flex flex-wrap items-center gap-3 rounded-xl border border-slate-200 bg-white/95 px-3.5 py-2 text-xs font-semibold text-slate-700 shadow-md backdrop-blur-xs">
        <span className="flex items-center gap-1.5">
          <span className="inline-block h-3 w-3 rounded-full border-2 border-slate-900 bg-amber-500" />
          {t.trips.mapLegend.pickup}
        </span>
        <span className="flex items-center gap-1.5">
          <span className="inline-block h-3 w-3 rounded-full border-2 border-white bg-emerald-500 shadow-xs" />
          {t.trips.mapLegend.dropoff}
        </span>
        <span className="flex items-center gap-1.5">
          <span className="inline-block h-3 w-3 rounded-full border-2 border-amber-500 bg-slate-900" />
          {t.trips.mapLegend.driver}
        </span>
      </div>
    </div>
  );
}
