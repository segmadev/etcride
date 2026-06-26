import { useEffect, useRef, useState } from 'react';

interface RichTextEditorProps {
  label?: React.ReactNode;
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
  helper?: string;
}

/**
 * Simple rich text editor using contentEditable.
 * Supports basic formatting: bold, italic, underline, headings, lists, links
 */
export function RichTextEditor({
  label,
  value,
  onChange,
  placeholder = 'Enter text…',
  helper,
}: RichTextEditorProps) {
  const editorRef = useRef<HTMLDivElement>(null);
  const [isFocused, setIsFocused] = useState(false);

  // Only update from prop if not focused
  useEffect(() => {
    if (editorRef.current && !isFocused && editorRef.current.innerHTML !== value) {
      editorRef.current.innerHTML = value || '';
    }
  }, [value, isFocused]);

  const handleInput = () => {
    if (editorRef.current) {
      onChange(editorRef.current.innerHTML);
    }
  };

  const handleFocus = () => {
    setIsFocused(true);
  };

  const handleBlur = () => {
    setIsFocused(false);
    if (editorRef.current) {
      onChange(editorRef.current.innerHTML);
    }
  };

  const execCommand = (command: string, value?: string) => {
    document.execCommand(command, false, value);
    editorRef.current?.focus();
  };

  return (
    <div className="col-span-full flex flex-col gap-2">
      {label && <label className="text-sm font-medium text-slate-700">{label}</label>}

      {/* Toolbar */}
      <div className="flex flex-wrap gap-1 border border-slate-300 rounded-t-lg bg-slate-50 p-2">
        <button
          type="button"
          onClick={() => execCommand('bold')}
          title="Bold (Ctrl+B)"
          className="p-2 rounded hover:bg-slate-200 text-sm font-bold text-slate-700"
        >
          B
        </button>
        <button
          type="button"
          onClick={() => execCommand('italic')}
          title="Italic (Ctrl+I)"
          className="p-2 rounded hover:bg-slate-200 text-sm italic text-slate-700"
        >
          I
        </button>
        <button
          type="button"
          onClick={() => execCommand('underline')}
          title="Underline (Ctrl+U)"
          className="p-2 rounded hover:bg-slate-200 text-sm underline text-slate-700"
        >
          U
        </button>

        <div className="mx-1 border-l border-slate-300" />

        <button
          type="button"
          onClick={() => execCommand('insertUnorderedList')}
          title="Bullet List"
          className="p-2 rounded hover:bg-slate-200 text-slate-700"
        >
          • List
        </button>
        <button
          type="button"
          onClick={() => execCommand('insertOrderedList')}
          title="Numbered List"
          className="p-2 rounded hover:bg-slate-200 text-slate-700"
        >
          1. List
        </button>

        <div className="mx-1 border-l border-slate-300" />

        <button
          type="button"
          onClick={() => execCommand('formatBlock', 'h2')}
          title="Heading 2"
          className="p-2 rounded hover:bg-slate-200 text-slate-700"
        >
          H2
        </button>
        <button
          type="button"
          onClick={() => execCommand('formatBlock', 'h3')}
          title="Heading 3"
          className="p-2 rounded hover:bg-slate-200 text-slate-700"
        >
          H3
        </button>

        <div className="mx-1 border-l border-slate-300" />

        <button
          type="button"
          onClick={() => {
            const url = prompt('Enter URL:');
            if (url) execCommand('createLink', url);
          }}
          title="Insert Link"
          className="p-2 rounded hover:bg-slate-200 text-slate-700"
        >
          🔗 Link
        </button>

        <button
          type="button"
          onClick={() => execCommand('removeFormat')}
          title="Clear Formatting"
          className="p-2 rounded hover:bg-slate-200 text-slate-700 ml-auto text-xs"
        >
          Clear
        </button>
      </div>

      {/* Editor */}
      <div
        ref={editorRef}
        onInput={handleInput}
        onFocus={handleFocus}
        onBlur={handleBlur}
        contentEditable
        suppressContentEditableWarning
        className="w-full h-80 p-3 border border-t-0 border-slate-300 rounded-b-lg bg-white text-slate-900 text-sm focus:outline-none focus:ring-2 focus:ring-brand-500 focus:border-brand-500 overflow-y-auto"
        style={{
          whiteSpace: 'pre-wrap',
          wordWrap: 'break-word',
        }}
        role="textbox"
        aria-label={label ? String(label) : 'Rich text editor'}
      />

      {helper && <p className="text-xs text-slate-500">{helper}</p>}
    </div>
  );
}
