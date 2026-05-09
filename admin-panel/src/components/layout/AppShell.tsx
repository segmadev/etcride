import { Suspense } from 'react';
import { Sidebar } from './Sidebar';

// Spinner shown in the main content area while a lazy page chunk downloads.
// The sidebar stays mounted — only the content flashes.
function PageSpinner() {
  return (
    <div className="flex flex-1 items-center justify-center">
      <div className="h-7 w-7 animate-spin rounded-full border-2 border-slate-200 border-t-brand-600" />
    </div>
  );
}

export function AppShell({ children }: { children: React.ReactNode }) {
  return (
    <div className="flex h-screen overflow-hidden bg-slate-50">
      <Sidebar />
      <main className="flex flex-1 flex-col overflow-hidden">
        <Suspense fallback={<PageSpinner />}>
          {children}
        </Suspense>
      </main>
    </div>
  );
}
