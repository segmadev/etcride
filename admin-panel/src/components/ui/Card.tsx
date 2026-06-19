import React from 'react';
import { cn } from '../../utils';

interface CardProps extends React.HTMLAttributes<HTMLDivElement> {
  children: React.ReactNode;
  className?: string;
  padding?: boolean;
}

export const Card = React.forwardRef<HTMLDivElement, CardProps>(
  ({ children, className, padding = true, ...rest }, ref) => (
    <div
      ref={ref}
      className={cn(
        'bg-white rounded-xl border border-slate-200 shadow-sm',
        padding && 'p-6',
        className,
      )}
      {...rest}
    >
      {children}
    </div>
  ),
);
Card.displayName = 'Card';

interface StatCardProps {
  title: string;
  value: string | number;
  sub?: string;
  icon: React.ReactNode;
  color?: string;
  trend?: { value: number; label: string };
}

export function StatCard({ title, value, sub, icon, color = 'bg-brand-50 text-brand-600', trend }: StatCardProps) {
  return (
    <Card className="flex items-start gap-4">
      <div className={cn('flex h-11 w-11 items-center justify-center rounded-lg shrink-0', color)}>
        {icon}
      </div>
      <div className="min-w-0 flex-1">
        <p className="text-sm text-slate-500 truncate">{title}</p>
        <p className="mt-0.5 text-2xl font-semibold text-slate-900">{value}</p>
        {sub && <p className="text-xs text-slate-400 mt-0.5">{sub}</p>}
        {trend && (
          <p className={cn('text-xs mt-1 font-medium', trend.value >= 0 ? 'text-green-600' : 'text-red-600')}>
            {trend.value >= 0 ? '↑' : '↓'} {Math.abs(trend.value)}% {trend.label}
          </p>
        )}
      </div>
    </Card>
  );
}
