import { useCallback, useEffect, useState } from 'react';
import { Truck } from 'lucide-react';
import { LanguageProvider, useLanguage } from './i18n/LanguageContext';
import { AuthProvider, useAuth } from './contexts/AuthContext';
import { ToastProvider } from './components/Toast';
import { Layout, type AdminRoute, type NavBadges } from './components/Layout';
import { LoginPage } from './pages/LoginPage';
import { OverviewPage } from './pages/OverviewPage';
import { DriversPage } from './pages/DriversPage';
import { ActiveTripsPage } from './pages/ActiveTripsPage';
import { ComplaintsPage } from './pages/ComplaintsPage';
import { UsersPage } from './pages/UsersPage';
import { WinchTypesPage } from './pages/WinchTypesPage';
import { supabase } from './lib/supabase';
import type { DashboardStats } from './types/database';

function AdminAppShell() {
  const { loading, isAuthorizedAdmin } = useAuth();
  const { t } = useLanguage();
  const [route, setRoute] = useState<AdminRoute>('overview');
  const [badges, setBadges] = useState<NavBadges>({});

  const applyStatsToBadges = useCallback((stats: DashboardStats) => {
    setBadges({
      pendingDrivers: stats.pending_driver_approvals,
      activeTrips: stats.active_trips_now + stats.searching_requests_now,
      openComplaints: stats.open_complaints,
    });
  }, []);

  useEffect(() => {
    if (!isAuthorizedAdmin) return;
    let active = true;
    async function loadBadges() {
      const { data } = await supabase.rpc('admin_get_dashboard_stats');
      if (active && data) {
        applyStatsToBadges(data as DashboardStats);
      }
    }
    void loadBadges();
    return () => {
      active = false;
    };
  }, [isAuthorizedAdmin, route, applyStatsToBadges]);

  if (loading) {
    return (
      <div className="flex min-h-screen flex-col items-center justify-center gap-4 bg-[#0F172A] text-white">
        <div className="flex h-14 w-14 animate-pulse items-center justify-center rounded-2xl bg-amber-500 text-slate-950 shadow-lg shadow-amber-500/25">
          <Truck className="h-7 w-7" />
        </div>
        <p className="text-sm font-semibold text-slate-300">{t.common.loading}</p>
      </div>
    );
  }

  if (!isAuthorizedAdmin) {
    return <LoginPage />;
  }

  return (
    <Layout activeRoute={route} onNavigate={setRoute} badges={badges}>
      {route === 'overview' && (
        <OverviewPage onNavigate={setRoute} onStatsLoaded={applyStatsToBadges} />
      )}
      {route === 'drivers' && <DriversPage />}
      {route === 'trips' && <ActiveTripsPage />}
      {route === 'complaints' && <ComplaintsPage />}
      {route === 'users' && <UsersPage />}
      {route === 'winchTypes' && <WinchTypesPage />}
    </Layout>
  );
}

export function App() {
  return (
    <LanguageProvider>
      <AuthProvider>
        <ToastProvider>
          <AdminAppShell />
        </ToastProvider>
      </AuthProvider>
    </LanguageProvider>
  );
}

export default App;
