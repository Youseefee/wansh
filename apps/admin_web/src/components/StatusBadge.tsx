import { useLanguage } from '../i18n/LanguageContext';
import type {
  AppRole,
  ComplaintStatus,
  DocumentReviewStatus,
  DriverApprovalStatus,
  TripStatus,
} from '../types/database';

type BadgeTone = 'amber' | 'emerald' | 'red' | 'slate' | 'blue' | 'purple';

const TONE_CLASSES: Record<BadgeTone, string> = {
  amber: 'bg-amber-50 text-amber-800 border-amber-200',
  emerald: 'bg-emerald-50 text-emerald-800 border-emerald-200',
  red: 'bg-red-50 text-red-800 border-red-200',
  slate: 'bg-slate-100 text-slate-700 border-slate-200',
  blue: 'bg-sky-50 text-sky-800 border-sky-200',
  purple: 'bg-indigo-50 text-indigo-800 border-indigo-200',
};

const DOT_CLASSES: Record<BadgeTone, string> = {
  amber: 'bg-amber-500',
  emerald: 'bg-emerald-500',
  red: 'bg-red-500',
  slate: 'bg-slate-400',
  blue: 'bg-sky-500',
  purple: 'bg-indigo-500',
};

export function Badge({
  label,
  tone = 'slate',
  dot = false,
}: {
  label: string;
  tone?: BadgeTone;
  dot?: boolean;
}) {
  return (
    <span
      className={`inline-flex items-center gap-1.5 rounded-full border px-2.5 py-0.5 text-xs font-semibold whitespace-nowrap ${TONE_CLASSES[tone]}`}
    >
      {dot && <span className={`h-1.5 w-1.5 rounded-full ${DOT_CLASSES[tone]}`} />}
      {label}
    </span>
  );
}

export function DriverStatusBadge({ status }: { status: DriverApprovalStatus }) {
  const { t } = useLanguage();
  const toneMap: Record<DriverApprovalStatus, BadgeTone> = {
    pending: 'amber',
    under_review: 'blue',
    approved: 'emerald',
    rejected: 'red',
    suspended: 'slate',
  };
  return <Badge label={t.statuses.driver[status]} tone={toneMap[status]} dot />;
}

export function DocumentStatusBadge({ status }: { status: DocumentReviewStatus }) {
  const { t } = useLanguage();
  const toneMap: Record<DocumentReviewStatus, BadgeTone> = {
    pending: 'amber',
    approved: 'emerald',
    rejected: 'red',
  };
  return <Badge label={t.statuses.document[status]} tone={toneMap[status]} dot />;
}

export function TripStatusBadge({ status }: { status: TripStatus }) {
  const { t } = useLanguage();
  const toneMap: Record<TripStatus, BadgeTone> = {
    searching: 'amber',
    driver_assigned: 'blue',
    en_route_to_pickup: 'blue',
    arrived_at_pickup: 'purple',
    vehicle_loaded: 'purple',
    en_route_to_dropoff: 'emerald',
    delivered: 'emerald',
    cancelled: 'red',
    expired: 'slate',
  };
  return <Badge label={t.statuses.trip[status]} tone={toneMap[status]} dot />;
}

export function ComplaintStatusBadge({ status }: { status: ComplaintStatus }) {
  const { t } = useLanguage();
  const toneMap: Record<ComplaintStatus, BadgeTone> = {
    open: 'red',
    in_progress: 'amber',
    resolved: 'emerald',
    dismissed: 'slate',
  };
  return <Badge label={t.statuses.complaint[status]} tone={toneMap[status]} dot />;
}

export function RoleBadge({ role }: { role: AppRole }) {
  const { t } = useLanguage();
  const toneMap: Record<AppRole, BadgeTone> = {
    admin: 'purple',
    driver: 'amber',
    customer: 'blue',
  };
  return <Badge label={t.statuses.role[role]} tone={toneMap[role]} />;
}
