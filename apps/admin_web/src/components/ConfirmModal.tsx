import { useEffect, useState } from 'react';
import { AlertTriangle, X } from 'lucide-react';
import { useLanguage } from '../i18n/LanguageContext';

interface ConfirmModalProps {
  open: boolean;
  title: string;
  description: string;
  confirmLabel?: string;
  variant?: 'danger' | 'primary';
  requireReason?: boolean;
  optionalReason?: boolean;
  loading?: boolean;
  onCancel: () => void;
  onConfirm: (reason: string) => void | Promise<void>;
}

export function ConfirmModal({
  open,
  title,
  description,
  confirmLabel,
  variant = 'danger',
  requireReason = false,
  optionalReason = false,
  loading = false,
  onCancel,
  onConfirm,
}: ConfirmModalProps) {
  const { t } = useLanguage();
  const [reason, setReason] = useState('');
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (open) {
      setReason('');
      setError(null);
    }
  }, [open]);

  if (!open) return null;

  const showReasonInput = requireReason || optionalReason;

  const handleConfirm = () => {
    if (requireReason && !reason.trim()) {
      setError(t.common.reasonRequired);
      return;
    }
    setError(null);
    void onConfirm(reason.trim());
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-950/60 p-4 backdrop-blur-xs">
      <div className="w-full max-w-md rounded-2xl border border-slate-200 bg-white p-6 shadow-2xl">
        <div className="flex items-start justify-between gap-3">
          <div className="flex items-center gap-3">
            <div
              className={`flex h-10 w-10 shrink-0 items-center justify-center rounded-xl ${
                variant === 'danger'
                  ? 'bg-red-50 text-red-600'
                  : 'bg-amber-50 text-amber-600'
              }`}
            >
              <AlertTriangle className="h-5 w-5" />
            </div>
            <h3 className="text-lg font-bold text-slate-900">{title}</h3>
          </div>
          <button
            type="button"
            onClick={onCancel}
            disabled={loading}
            className="rounded-lg p-1.5 text-slate-400 hover:bg-slate-100 hover:text-slate-600"
          >
            <X className="h-5 w-5" />
          </button>
        </div>

        <p className="mt-3 text-sm leading-relaxed text-slate-600">{description}</p>

        {showReasonInput && (
          <div className="mt-4">
            <label className="mb-1.5 block text-xs font-semibold text-slate-700">
              {t.common.reason} {requireReason && <span className="text-red-500">*</span>}
            </label>
            <textarea
              rows={3}
              value={reason}
              onChange={(e) => {
                setReason(e.target.value);
                if (error) setError(null);
              }}
              placeholder={t.common.reasonPlaceholder}
              className="w-full rounded-xl border border-slate-300 px-3 py-2 text-sm text-slate-900 focus:border-amber-500 focus:outline-none focus:ring-2 focus:ring-amber-500/20"
            />
            {error && <p className="mt-1 text-xs font-medium text-red-600">{error}</p>}
          </div>
        )}

        <div className="mt-6 flex items-center justify-end gap-2.5">
          <button
            type="button"
            onClick={onCancel}
            disabled={loading}
            className="rounded-xl border border-slate-200 bg-white px-4 py-2 text-sm font-semibold text-slate-700 hover:bg-slate-50 disabled:opacity-50"
          >
            {t.common.cancel}
          </button>
          <button
            type="button"
            onClick={handleConfirm}
            disabled={loading}
            className={`rounded-xl px-4 py-2 text-sm font-semibold text-white shadow-xs transition disabled:opacity-50 ${
              variant === 'danger'
                ? 'bg-red-600 hover:bg-red-700'
                : 'bg-amber-500 text-slate-950 hover:bg-amber-600'
            }`}
          >
            {loading ? t.common.saving : confirmLabel ?? t.common.confirm}
          </button>
        </div>
      </div>
    </div>
  );
}
