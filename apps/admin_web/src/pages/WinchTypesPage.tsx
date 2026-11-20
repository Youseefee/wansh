import React, { useCallback, useEffect, useState } from 'react';
import {
  Truck,
  Plus,
  Pencil,
  RefreshCw,
  X,
  Scale,
  Gauge,
  TrendingUp,
  Calculator,
  Power,
} from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useLanguage } from '../i18n/LanguageContext';
import { useToast } from '../components/Toast';
import { formatCurrency } from '../lib/format';
import { Badge } from '../components/StatusBadge';
import type { WinchType } from '../types/database';

interface WinchFormState {
  id: string | null;
  code: string;
  name_ar: string;
  name_en: string;
  description_ar: string;
  description_en: string;
  base_fare: string;
  price_per_km: string;
  minimum_fare: string;
  road_factor: string;
  surge_multiplier: string;
  max_weight_tons: string;
  sort_order: string;
  icon_name: string;
  is_active: boolean;
}

const EMPTY_FORM: WinchFormState = {
  id: null,
  code: '',
  name_ar: '',
  name_en: '',
  description_ar: '',
  description_en: '',
  base_fare: '250',
  price_per_km: '25',
  minimum_fare: '350',
  road_factor: '1.25',
  surge_multiplier: '1.00',
  max_weight_tons: '3.5',
  sort_order: '0',
  icon_name: 'truck',
  is_active: true,
};

function computeSample10KmQuote(
  baseFare: number,
  pricePerKm: number,
  minimumFare: number,
  roadFactor: number,
  surgeMultiplier: number
): number {
  const effectiveKm = 10 * (Number.isFinite(roadFactor) ? roadFactor : 1.25);
  const raw =
    (Number.isFinite(baseFare) ? baseFare : 0) +
    effectiveKm * (Number.isFinite(pricePerKm) ? pricePerKm : 0);
  const surged = raw * (Number.isFinite(surgeMultiplier) ? surgeMultiplier : 1);
  return Math.max(Number.isFinite(minimumFare) ? minimumFare : 0, Math.round(surged * 100) / 100);
}

export function WinchTypesPage() {
  const { locale, t } = useLanguage();
  const { showToast } = useToast();

  const [items, setItems] = useState<WinchType[]>([]);
  const [loading, setLoading] = useState(true);
  const [modalOpen, setModalOpen] = useState(false);
  const [form, setForm] = useState<WinchFormState>(EMPTY_FORM);
  const [saving, setSaving] = useState(false);

  const fetchWinchTypes = useCallback(async () => {
    setLoading(true);
    const { data, error } = await supabase
      .from('winch_types')
      .select('*')
      .order('sort_order', { ascending: true })
      .order('created_at', { ascending: true });

    if (error) {
      showToast(error.message, 'error');
    } else {
      setItems((data ?? []) as WinchType[]);
    }
    setLoading(false);
  }, [showToast]);

  useEffect(() => {
    void fetchWinchTypes();
  }, [fetchWinchTypes]);

  const openCreateModal = () => {
    setForm({ ...EMPTY_FORM, sort_order: String(items.length + 1) });
    setModalOpen(true);
  };

  const openEditModal = (item: WinchType) => {
    setForm({
      id: item.id,
      code: item.code,
      name_ar: item.name_ar,
      name_en: item.name_en,
      description_ar: item.description_ar ?? '',
      description_en: item.description_en ?? '',
      base_fare: String(item.base_fare),
      price_per_km: String(item.price_per_km),
      minimum_fare: String(item.minimum_fare),
      road_factor: String(item.road_factor),
      surge_multiplier: String(item.surge_multiplier),
      max_weight_tons: item.max_weight_tons !== null ? String(item.max_weight_tons) : '',
      sort_order: String(item.sort_order),
      icon_name: item.icon_name ?? '',
      is_active: item.is_active,
    });
    setModalOpen(true);
  };

  const handleToggleActive = async (item: WinchType) => {
    const next = !item.is_active;
    const { error } = await supabase
      .from('winch_types')
      .update({ is_active: next })
      .eq('id', item.id);

    if (error) {
      showToast(error.message, 'error');
      return;
    }
    setItems((prev) => prev.map((w) => (w.id === item.id ? { ...w, is_active: next } : w)));
    showToast(t.winchTypes.toggledToast, 'success');
  };

  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault();
    setSaving(true);

    const payload = {
      code: form.code.trim().toLowerCase(),
      name_ar: form.name_ar.trim(),
      name_en: form.name_en.trim(),
      description_ar: form.description_ar.trim() || null,
      description_en: form.description_en.trim() || null,
      base_fare: Number(form.base_fare),
      price_per_km: Number(form.price_per_km),
      minimum_fare: Number(form.minimum_fare),
      road_factor: Number(form.road_factor),
      surge_multiplier: Number(form.surge_multiplier),
      max_weight_tons: form.max_weight_tons.trim() ? Number(form.max_weight_tons) : null,
      sort_order: Number(form.sort_order) || 0,
      icon_name: form.icon_name.trim() || null,
      is_active: form.is_active,
    };

    const { error } = form.id
      ? await supabase.from('winch_types').update(payload).eq('id', form.id)
      : await supabase.from('winch_types').insert(payload);

    setSaving(false);

    if (error) {
      showToast(error.message, 'error');
      return;
    }

    showToast(form.id ? t.winchTypes.savedToast : t.winchTypes.createdToast, 'success');
    setModalOpen(false);
    await fetchWinchTypes();
  };

  const previewQuote = computeSample10KmQuote(
    Number(form.base_fare),
    Number(form.price_per_km),
    Number(form.minimum_fare),
    Number(form.road_factor),
    Number(form.surge_multiplier)
  );

  return (
    <div className="space-y-5">
      {/* Header */}
      <div className="flex flex-col justify-between gap-3 sm:flex-row sm:items-center">
        <div>
          <h2 className="text-xl font-extrabold text-slate-900">{t.winchTypes.title}</h2>
          <p className="mt-0.5 text-sm text-slate-500">{t.winchTypes.subtitle}</p>
        </div>
        <div className="flex items-center gap-2">
          <button
            type="button"
            onClick={() => void fetchWinchTypes()}
            className="inline-flex items-center gap-1.5 rounded-xl border border-slate-200 bg-white px-3.5 py-2 text-xs font-bold text-slate-700 hover:bg-slate-50"
          >
            <RefreshCw className={`h-4 w-4 ${loading ? 'animate-spin' : ''}`} />
            <span>{t.common.refresh}</span>
          </button>
          <button
            type="button"
            onClick={openCreateModal}
            className="inline-flex items-center gap-1.5 rounded-xl bg-amber-500 px-4 py-2 text-xs font-extrabold text-slate-950 shadow-xs transition hover:bg-amber-400"
          >
            <Plus className="h-4 w-4" />
            <span>{t.winchTypes.addNew}</span>
          </button>
        </div>
      </div>

      {/* Catalog Grid */}
      {loading ? (
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-3">
          {Array.from({ length: 3 }).map((_, idx) => (
            <div
              key={idx}
              className="h-64 animate-pulse rounded-2xl border border-slate-200 bg-white p-5"
            />
          ))}
        </div>
      ) : items.length === 0 ? (
        <div className="rounded-2xl border border-slate-200 bg-white p-12 text-center text-sm text-slate-500">
          {t.common.noData}
        </div>
      ) : (
        <div className="grid grid-cols-1 gap-5 md:grid-cols-2 xl:grid-cols-3">
          {items.map((item) => {
            const sample10 = computeSample10KmQuote(
              item.base_fare,
              item.price_per_km,
              item.minimum_fare,
              item.road_factor,
              item.surge_multiplier
            );

            return (
              <div
                key={item.id}
                className={`flex flex-col justify-between rounded-2xl border bg-white p-5 shadow-2xs transition ${
                  item.is_active ? 'border-slate-200' : 'border-slate-200 opacity-70'
                }`}
              >
                <div>
                  {/* Card Top */}
                  <div className="flex items-start justify-between gap-3">
                    <div className="flex items-center gap-3">
                      <div className="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl bg-slate-900 text-amber-400">
                        <Truck className="h-5 w-5" />
                      </div>
                      <div>
                        <h3 className="text-base font-extrabold text-slate-900">
                          {locale === 'ar' ? item.name_ar : item.name_en}
                        </h3>
                        <p className="text-xs font-medium text-slate-500">
                          {locale === 'ar' ? item.name_en : item.name_ar} ·{' '}
                          <span className="font-mono">{item.code}</span>
                        </p>
                      </div>
                    </div>
                    <Badge
                      label={item.is_active ? t.common.active : t.common.inactive}
                      tone={item.is_active ? 'emerald' : 'slate'}
                      dot
                    />
                  </div>

                  {(item.description_ar || item.description_en) && (
                    <p className="mt-3 text-xs leading-relaxed text-slate-600 line-clamp-2">
                      {locale === 'ar'
                        ? item.description_ar || item.description_en
                        : item.description_en || item.description_ar}
                    </p>
                  )}

                  {/* Pricing Grid */}
                  <div className="mt-4 grid grid-cols-3 gap-2">
                    <div className="rounded-xl bg-slate-50 p-2.5">
                      <p className="text-[10px] font-bold text-slate-500">
                        {t.winchTypes.baseFare}
                      </p>
                      <p className="mt-0.5 text-sm font-extrabold text-slate-900">
                        {formatCurrency(item.base_fare, locale)}
                      </p>
                    </div>
                    <div className="rounded-xl bg-slate-50 p-2.5">
                      <p className="text-[10px] font-bold text-slate-500">
                        {t.winchTypes.pricePerKm}
                      </p>
                      <p className="mt-0.5 text-sm font-extrabold text-slate-900">
                        {formatCurrency(item.price_per_km, locale)}
                      </p>
                    </div>
                    <div className="rounded-xl bg-slate-50 p-2.5">
                      <p className="text-[10px] font-bold text-slate-500">
                        {t.winchTypes.minimumFare}
                      </p>
                      <p className="mt-0.5 text-sm font-extrabold text-slate-900">
                        {formatCurrency(item.minimum_fare, locale)}
                      </p>
                    </div>
                  </div>

                  {/* Multipliers & Capacity */}
                  <div className="mt-3 flex flex-wrap items-center gap-3 text-xs text-slate-600">
                    <span className="inline-flex items-center gap-1 rounded-lg bg-slate-100 px-2 py-1 font-semibold">
                      <Gauge className="h-3.5 w-3.5 text-slate-500" />
                      ×{Number(item.road_factor).toFixed(2)}
                    </span>
                    <span
                      className={`inline-flex items-center gap-1 rounded-lg px-2 py-1 font-bold ${
                        item.surge_multiplier > 1
                          ? 'bg-amber-100 text-amber-800'
                          : 'bg-slate-100 text-slate-600'
                      }`}
                    >
                      <TrendingUp className="h-3.5 w-3.5" />
                      {Number(item.surge_multiplier).toFixed(2)}x
                    </span>
                    {item.max_weight_tons !== null && (
                      <span className="inline-flex items-center gap-1 rounded-lg bg-slate-100 px-2 py-1 font-semibold">
                        <Scale className="h-3.5 w-3.5 text-slate-500" />
                        {item.max_weight_tons} {t.winchTypes.tonsUnit}
                      </span>
                    )}
                  </div>

                  {/* 10km Sample Estimate */}
                  <div className="mt-3 flex items-center justify-between rounded-xl border border-amber-200/80 bg-amber-50/60 px-3 py-2 text-xs">
                    <span className="inline-flex items-center gap-1.5 font-semibold text-amber-900">
                      <Calculator className="h-3.5 w-3.5 text-amber-600" />
                      10 km
                    </span>
                    <span className="font-extrabold text-slate-900">
                      {formatCurrency(sample10, locale)}
                    </span>
                  </div>
                </div>

                {/* Card Actions */}
                <div className="mt-4 flex items-center gap-2 border-t border-slate-100 pt-3.5">
                  <button
                    type="button"
                    onClick={() => openEditModal(item)}
                    className="flex flex-1 items-center justify-center gap-1.5 rounded-xl bg-slate-900 px-3 py-2 text-xs font-bold text-white transition hover:bg-amber-500 hover:text-slate-950"
                  >
                    <Pencil className="h-3.5 w-3.5" />
                    <span>{t.common.edit}</span>
                  </button>
                  <button
                    type="button"
                    onClick={() => void handleToggleActive(item)}
                    className={`inline-flex items-center justify-center gap-1.5 rounded-xl border px-3 py-2 text-xs font-bold transition ${
                      item.is_active
                        ? 'border-slate-200 bg-white text-slate-700 hover:bg-red-50 hover:text-red-700 hover:border-red-200'
                        : 'border-emerald-200 bg-emerald-50 text-emerald-700 hover:bg-emerald-100'
                    }`}
                  >
                    <Power className="h-3.5 w-3.5" />
                    <span>{item.is_active ? t.common.inactive : t.common.active}</span>
                  </button>
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* Edit / Create Winch Type Modal */}
      {modalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-950/60 p-4 backdrop-blur-xs">
          <div className="flex max-h-[92vh] w-full max-w-2xl flex-col overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-2xl">
            <div className="flex items-center justify-between border-b border-slate-200 bg-[#0F172A] px-6 py-4 text-white">
              <h3 className="text-base font-extrabold">
                {form.id ? t.winchTypes.editType : t.winchTypes.addNew}
              </h3>
              <button
                type="button"
                onClick={() => setModalOpen(false)}
                className="rounded-lg p-1.5 text-slate-400 hover:bg-slate-800 hover:text-white"
              >
                <X className="h-5 w-5" />
              </button>
            </div>

            <form onSubmit={handleSave} className="flex-1 space-y-4 overflow-y-auto p-6">
              <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
                <div>
                  <label className="mb-1 block text-xs font-bold text-slate-700">
                    {t.winchTypes.code} *
                  </label>
                  <input
                    type="text"
                    required
                    disabled={Boolean(form.id)}
                    value={form.code}
                    onChange={(e) => setForm((f) => ({ ...f, code: e.target.value }))}
                    placeholder="flatbed_hydraulic"
                    dir="ltr"
                    className="w-full rounded-xl border border-slate-300 px-3 py-2 text-sm font-mono text-slate-900 disabled:bg-slate-100 disabled:text-slate-500 focus:border-amber-500 focus:outline-none"
                  />
                </div>
                <div>
                  <label className="mb-1 block text-xs font-bold text-slate-700">
                    {t.winchTypes.sortOrder}
                  </label>
                  <input
                    type="number"
                    value={form.sort_order}
                    onChange={(e) => setForm((f) => ({ ...f, sort_order: e.target.value }))}
                    className="w-full rounded-xl border border-slate-300 px-3 py-2 text-sm text-slate-900 focus:border-amber-500 focus:outline-none"
                  />
                </div>

                <div>
                  <label className="mb-1 block text-xs font-bold text-slate-700">
                    {t.winchTypes.nameAr} *
                  </label>
                  <input
                    type="text"
                    required
                    value={form.name_ar}
                    onChange={(e) => setForm((f) => ({ ...f, name_ar: e.target.value }))}
                    dir="rtl"
                    className="w-full rounded-xl border border-slate-300 px-3 py-2 text-sm text-slate-900 focus:border-amber-500 focus:outline-none"
                  />
                </div>
                <div>
                  <label className="mb-1 block text-xs font-bold text-slate-700">
                    {t.winchTypes.nameEn} *
                  </label>
                  <input
                    type="text"
                    required
                    value={form.name_en}
                    onChange={(e) => setForm((f) => ({ ...f, name_en: e.target.value }))}
                    dir="ltr"
                    className="w-full rounded-xl border border-slate-300 px-3 py-2 text-sm text-slate-900 focus:border-amber-500 focus:outline-none"
                  />
                </div>

                <div>
                  <label className="mb-1 block text-xs font-bold text-slate-700">
                    {t.winchTypes.descAr}
                  </label>
                  <textarea
                    rows={2}
                    value={form.description_ar}
                    onChange={(e) => setForm((f) => ({ ...f, description_ar: e.target.value }))}
                    dir="rtl"
                    className="w-full rounded-xl border border-slate-300 px-3 py-2 text-sm text-slate-900 focus:border-amber-500 focus:outline-none"
                  />
                </div>
                <div>
                  <label className="mb-1 block text-xs font-bold text-slate-700">
                    {t.winchTypes.descEn}
                  </label>
                  <textarea
                    rows={2}
                    value={form.description_en}
                    onChange={(e) => setForm((f) => ({ ...f, description_en: e.target.value }))}
                    dir="ltr"
                    className="w-full rounded-xl border border-slate-300 px-3 py-2 text-sm text-slate-900 focus:border-amber-500 focus:outline-none"
                  />
                </div>
              </div>

              {/* Pricing Fields */}
              <div className="grid grid-cols-1 gap-4 rounded-2xl border border-slate-200 bg-slate-50 p-4 sm:grid-cols-3">
                <div>
                  <label className="mb-1 block text-xs font-bold text-slate-700">
                    {t.winchTypes.baseFare} *
                  </label>
                  <input
                    type="number"
                    required
                    min="0"
                    step="0.01"
                    value={form.base_fare}
                    onChange={(e) => setForm((f) => ({ ...f, base_fare: e.target.value }))}
                    className="w-full rounded-xl border border-slate-300 bg-white px-3 py-2 text-sm font-bold text-slate-900 focus:border-amber-500 focus:outline-none"
                  />
                </div>
                <div>
                  <label className="mb-1 block text-xs font-bold text-slate-700">
                    {t.winchTypes.pricePerKm} *
                  </label>
                  <input
                    type="number"
                    required
                    min="0"
                    step="0.01"
                    value={form.price_per_km}
                    onChange={(e) => setForm((f) => ({ ...f, price_per_km: e.target.value }))}
                    className="w-full rounded-xl border border-slate-300 bg-white px-3 py-2 text-sm font-bold text-slate-900 focus:border-amber-500 focus:outline-none"
                  />
                </div>
                <div>
                  <label className="mb-1 block text-xs font-bold text-slate-700">
                    {t.winchTypes.minimumFare} *
                  </label>
                  <input
                    type="number"
                    required
                    min="0"
                    step="0.01"
                    value={form.minimum_fare}
                    onChange={(e) => setForm((f) => ({ ...f, minimum_fare: e.target.value }))}
                    className="w-full rounded-xl border border-slate-300 bg-white px-3 py-2 text-sm font-bold text-slate-900 focus:border-amber-500 focus:outline-none"
                  />
                </div>
                <div>
                  <label className="mb-1 block text-xs font-bold text-slate-700">
                    {t.winchTypes.roadFactor} *
                  </label>
                  <input
                    type="number"
                    required
                    min="1.00"
                    max="3.00"
                    step="0.01"
                    value={form.road_factor}
                    onChange={(e) => setForm((f) => ({ ...f, road_factor: e.target.value }))}
                    className="w-full rounded-xl border border-slate-300 bg-white px-3 py-2 text-sm font-bold text-slate-900 focus:border-amber-500 focus:outline-none"
                  />
                </div>
                <div>
                  <label className="mb-1 block text-xs font-bold text-slate-700">
                    {t.winchTypes.surgeMultiplier} *
                  </label>
                  <input
                    type="number"
                    required
                    min="0.50"
                    max="5.00"
                    step="0.05"
                    value={form.surge_multiplier}
                    onChange={(e) => setForm((f) => ({ ...f, surge_multiplier: e.target.value }))}
                    className="w-full rounded-xl border border-slate-300 bg-white px-3 py-2 text-sm font-bold text-slate-900 focus:border-amber-500 focus:outline-none"
                  />
                </div>
                <div>
                  <label className="mb-1 block text-xs font-bold text-slate-700">
                    {t.winchTypes.maxWeightTons}
                  </label>
                  <input
                    type="number"
                    min="0.1"
                    step="0.1"
                    value={form.max_weight_tons}
                    onChange={(e) => setForm((f) => ({ ...f, max_weight_tons: e.target.value }))}
                    className="w-full rounded-xl border border-slate-300 bg-white px-3 py-2 text-sm font-bold text-slate-900 focus:border-amber-500 focus:outline-none"
                  />
                </div>
              </div>

              {/* Live Sample Quote Calculator */}
              <div className="flex flex-col justify-between gap-2 rounded-2xl border border-amber-200 bg-amber-50 px-4 py-3 sm:flex-row sm:items-center">
                <div>
                  <p className="text-xs font-extrabold text-amber-950">
                    {t.winchTypes.sampleQuoteTitle}
                  </p>
                  <p className="text-[11px] text-amber-800">{t.winchTypes.sampleQuoteFormula}</p>
                </div>
                <p className="text-xl font-extrabold text-slate-950">
                  {formatCurrency(previewQuote, locale)}
                </p>
              </div>

              <label className="flex cursor-pointer items-center gap-2.5 text-sm font-bold text-slate-800">
                <input
                  type="checkbox"
                  checked={form.is_active}
                  onChange={(e) => setForm((f) => ({ ...f, is_active: e.target.checked }))}
                  className="h-4 w-4 rounded accent-amber-500"
                />
                <span>{t.winchTypes.isActive}</span>
              </label>

              <div className="flex items-center justify-end gap-2.5 border-t border-slate-100 pt-4">
                <button
                  type="button"
                  onClick={() => setModalOpen(false)}
                  disabled={saving}
                  className="rounded-xl border border-slate-200 bg-white px-4 py-2 text-sm font-semibold text-slate-700 hover:bg-slate-50"
                >
                  {t.common.cancel}
                </button>
                <button
                  type="submit"
                  disabled={saving}
                  className="rounded-xl bg-amber-500 px-5 py-2 text-sm font-extrabold text-slate-950 shadow-xs transition hover:bg-amber-400 disabled:opacity-60"
                >
                  {saving ? t.common.saving : t.common.save}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
