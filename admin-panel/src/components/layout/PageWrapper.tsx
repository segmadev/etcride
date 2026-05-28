import React from 'react';
import { Header } from './Header';

interface PageWrapperProps {
  title: string;
  subtitle?: string;
  actions?: React.ReactNode;
  children: React.ReactNode;
}

export function PageWrapper({ title, subtitle, actions, children }: PageWrapperProps) {
  return (
    <div className="flex flex-1 flex-col overflow-hidden">
      <Header title={title} subtitle={subtitle} />
      <div className="flex-1 overflow-y-auto p-3 md:p-6 scrollbar-thin">
        {actions && (
          <div className="mb-4 flex items-center justify-between gap-3">
            {actions}
          </div>
        )}
        {children}
      </div>
    </div>
  );
}
