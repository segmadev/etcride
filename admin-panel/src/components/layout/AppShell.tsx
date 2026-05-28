import { Suspense } from 'react';
import { Sidebar } from './Sidebar';
import { SidebarProvider } from './SidebarContext';

function PageSpinner() {
  return (
    <div className="flex flex-1 items-center justify-center">
      <div className="h-7 w-7 animate-spin rounded-full border-2 border-slate-200 border-t-brand-600" />
    </div>
  );
}

export function AppShell({ children }: { children: React.ReactNode }) {
  return (
    <SidebarProvider>
      <div className="flex h-screen overflow-hidden bg-slate-50">
        <Sidebar />
        <main className="flex flex-1 flex-col overflow-hidden min-w-0">
          <Suspense fallback={<PageSpinner />}>
            {children}
          </Suspense>
        </main>
      </div>
    </SidebarProvider>
  );
}
