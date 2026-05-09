import { ChevronLeft, ChevronRight } from 'lucide-react';
import { cn } from '../../utils';

interface PaginationProps {
  page: number;
  total: number;
  perPage: number;
  onChange: (page: number) => void;
}

export function Pagination({ page, total, perPage, onChange }: PaginationProps) {
  const totalPages = Math.ceil(total / perPage);
  if (totalPages <= 1) return null;

  const from = (page - 1) * perPage + 1;
  const to   = Math.min(page * perPage, total);

  return (
    <div className="flex items-center justify-between px-4 py-3 border-t border-slate-200">
      <span className="text-sm text-slate-500">
        Showing {from}–{to} of {total}
      </span>
      <div className="flex items-center gap-1">
        <button
          onClick={() => onChange(page - 1)}
          disabled={page <= 1}
          className="flex h-8 w-8 items-center justify-center rounded-lg border border-slate-200 text-slate-600 hover:bg-slate-50 disabled:opacity-40 disabled:cursor-not-allowed"
        >
          <ChevronLeft size={14} />
        </button>

        {Array.from({ length: totalPages }, (_, i) => i + 1)
          .filter(p => p === 1 || p === totalPages || Math.abs(p - page) <= 1)
          .reduce<(number | '...')[]>((acc, p, idx, arr) => {
            if (idx > 0 && typeof arr[idx - 1] === 'number' && (p as number) - (arr[idx - 1] as number) > 1) {
              acc.push('...');
            }
            acc.push(p);
            return acc;
          }, [])
          .map((p, i) =>
            p === '...' ? (
              <span key={`ellipsis-${i}`} className="px-1 text-slate-400 text-sm">…</span>
            ) : (
              <button
                key={p}
                onClick={() => onChange(p as number)}
                className={cn(
                  'h-8 min-w-[2rem] px-2 rounded-lg text-sm font-medium transition-colors',
                  p === page
                    ? 'bg-brand-600 text-white'
                    : 'border border-slate-200 text-slate-600 hover:bg-slate-50',
                )}
              >
                {p}
              </button>
            ),
          )}

        <button
          onClick={() => onChange(page + 1)}
          disabled={page >= totalPages}
          className="flex h-8 w-8 items-center justify-center rounded-lg border border-slate-200 text-slate-600 hover:bg-slate-50 disabled:opacity-40 disabled:cursor-not-allowed"
        >
          <ChevronRight size={14} />
        </button>
      </div>
    </div>
  );
}
