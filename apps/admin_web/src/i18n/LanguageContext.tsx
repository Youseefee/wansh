import React, { createContext, useContext, useEffect, useState } from 'react';
import { translations, type Translations } from './translations';
import type { Locale } from '../lib/format';

interface LanguageContextValue {
  locale: Locale;
  isRtl: boolean;
  t: Translations;
  setLocale: (locale: Locale) => void;
  toggleLocale: () => void;
}

const STORAGE_KEY = 'wenshy_admin_locale';

const LanguageContext = createContext<LanguageContextValue | undefined>(undefined);

export function LanguageProvider({ children }: { children: React.ReactNode }) {
  const [locale, setLocaleState] = useState<Locale>(() => {
    try {
      const saved = window.localStorage.getItem(STORAGE_KEY);
      if (saved === 'en' || saved === 'ar') return saved;
    } catch {
      // Ignore storage access errors
    }
    return 'ar';
  });

  const isRtl = locale === 'ar';

  useEffect(() => {
    document.documentElement.lang = locale;
    document.documentElement.dir = isRtl ? 'rtl' : 'ltr';
    document.title =
      locale === 'ar'
        ? 'ونشي | لوحة تحكم الإدارة'
        : 'Wenshy | Operations & Admin Dashboard';
    try {
      window.localStorage.setItem(STORAGE_KEY, locale);
    } catch {
      // Ignore storage access errors
    }
  }, [locale, isRtl]);

  const setLocale = (next: Locale) => setLocaleState(next);
  const toggleLocale = () => setLocaleState((prev) => (prev === 'ar' ? 'en' : 'ar'));

  return (
    <LanguageContext.Provider
      value={{
        locale,
        isRtl,
        t: translations[locale],
        setLocale,
        toggleLocale,
      }}
    >
      {children}
    </LanguageContext.Provider>
  );
}

export function useLanguage(): LanguageContextValue {
  const ctx = useContext(LanguageContext);
  if (!ctx) {
    throw new Error('useLanguage must be used within LanguageProvider');
  }
  return ctx;
}
