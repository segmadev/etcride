import { Info } from 'lucide-react';
import { useState, useRef, useEffect } from 'react';

interface InfoTooltipProps {
  content: string;
  /** Optional title shown in bold above the content */
  title?: string;
  /** Where the tooltip opens. Default: 'top' */
  position?: 'top' | 'bottom' | 'left' | 'right';
  size?: number;
}

export function InfoTooltip({ content, title, position = 'top', size = 14 }: InfoTooltipProps) {
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);

  // Close when clicking outside
  useEffect(() => {
    if (!open) return;
    const handler = (e: MouseEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener('mousedown', handler);
    return () => document.removeEventListener('mousedown', handler);
  }, [open]);

  const positionClasses: Record<string, string> = {
    top:    'bottom-full left-1/2 -translate-x-1/2 mb-2',
    bottom: 'top-full  left-1/2 -translate-x-1/2 mt-2',
    left:   'right-full top-1/2 -translate-y-1/2 mr-2',
    right:  'left-full  top-1/2 -translate-y-1/2 ml-2',
  };

  const arrowClasses: Record<string, string> = {
    top:    'top-full  left-1/2 -translate-x-1/2 border-t-slate-800',
    bottom: 'bottom-full left-1/2 -translate-x-1/2 border-b-slate-800',
    left:   'left-full  top-1/2 -translate-y-1/2 border-l-slate-800',
    right:  'right-full top-1/2 -translate-y-1/2 border-r-slate-800',
  };

  return (
    <div ref={ref} className="relative inline-flex items-center">
      <button
        type="button"
        onClick={() => setOpen(s => !s)}
        onMouseEnter={() => setOpen(true)}
        onMouseLeave={() => setOpen(false)}
        className="text-slate-400 hover:text-brand-500 transition-colors focus:outline-none"
        aria-label="More information"
      >
        <Info size={size} />
      </button>

      {open && (
        <div
          className={`absolute z-50 w-64 rounded-xl bg-slate-800 text-white shadow-xl p-3 text-xs leading-relaxed pointer-events-none ${positionClasses[position]}`}
        >
          {title && <p className="font-semibold mb-1 text-white">{title}</p>}
          <p className="text-slate-300">{content}</p>
          {/* Arrow */}
          <span className={`absolute border-4 border-transparent ${arrowClasses[position]}`} />
        </div>
      )}
    </div>
  );
}
