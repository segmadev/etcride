import { type ClassValue, clsx } from 'clsx';

export function cn(...inputs: ClassValue[]) {
  return clsx(inputs);
}

export function formatCurrency(amount: number | string, symbol = '₦'): string {
  const num = typeof amount === 'string' ? parseFloat(amount) : amount;
  if (isNaN(num)) return `${symbol}0.00`;
  return `${symbol}${num.toLocaleString('en-NG', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
}

export function formatDate(dateStr: string | null | undefined): string {
  if (!dateStr) return '—';
  return new Date(dateStr).toLocaleDateString('en-NG', {
    day: '2-digit', month: 'short', year: 'numeric',
  });
}

export function formatDateTime(dateStr: string | null | undefined): string {
  if (!dateStr) return '—';
  return new Date(dateStr).toLocaleString('en-NG', {
    day: '2-digit', month: 'short', year: 'numeric',
    hour: '2-digit', minute: '2-digit',
  });
}

export function getInitials(name: string): string {
  return name
    .split(' ')
    .map(n => n[0])
    .slice(0, 2)
    .join('')
    .toUpperCase();
}

export function statusColor(status: string): string {
  const map: Record<string, string> = {
    pending:         'bg-yellow-100 text-yellow-800',
    assigned:        'bg-blue-100 text-blue-800',
    accepted:        'bg-indigo-100 text-indigo-800',
    payment_pending: 'bg-orange-100 text-orange-800',
    paid:            'bg-teal-100 text-teal-800',
    failed:          'bg-red-100 text-red-800',
    refunded:        'bg-orange-100 text-orange-800',
    in_progress:     'bg-purple-100 text-purple-800',
    completed:       'bg-green-100 text-green-800',
    cancelled:       'bg-red-100 text-red-800',
    active:          'bg-green-100 text-green-800',
    inactive:        'bg-gray-100 text-gray-600',
    online:          'bg-green-100 text-green-700',
    offline:         'bg-gray-100 text-gray-500',
  };
  return map[status] ?? 'bg-gray-100 text-gray-600';
}

export function statusLabel(status: string): string {
  return status.replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase());
}
