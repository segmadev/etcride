import React from 'react';
import { cn, statusColor, statusLabel } from '../../utils';

interface BadgeProps {
  children?: React.ReactNode;
  status?: string;
  className?: string;
  dot?: boolean;
}

export function Badge({ children, status, className, dot }: BadgeProps) {
  const colorClass = status ? statusColor(status) : 'bg-gray-100 text-gray-600';
  return (
    <span
      className={cn(
        'inline-flex items-center gap-1.5 rounded-full px-2.5 py-0.5 text-xs font-medium',
        colorClass,
        className,
      )}
    >
      {dot && <span className="w-1.5 h-1.5 rounded-full bg-current opacity-70" />}
      {children ?? (status ? statusLabel(status) : null)}
    </span>
  );
}
