import { useEffect, useCallback } from 'react';
import { useEditor, EditorContent } from '@tiptap/react';
import StarterKit from '@tiptap/starter-kit';
import Underline from '@tiptap/extension-underline';
import TextAlign from '@tiptap/extension-text-align';
import { TextStyle } from '@tiptap/extension-text-style';
import { Color } from '@tiptap/extension-color';
import Link from '@tiptap/extension-link';
import Image from '@tiptap/extension-image';
import Placeholder from '@tiptap/extension-placeholder';
import {
  Bold, Italic, Underline as UnderlineIcon, AlignLeft, AlignCenter, AlignRight,
  List, ListOrdered, Link as LinkIcon, Image as ImageIcon, Undo, Redo,
  Heading2, Heading3, Minus,
} from 'lucide-react';

// ── Toolbar button ─────────────────────────────────────────────────────────────

function ToolBtn({
  onClick, active, disabled, title, children,
}: {
  onClick: () => void; active?: boolean; disabled?: boolean; title: string; children: React.ReactNode;
}) {
  return (
    <button
      type="button"
      title={title}
      onMouseDown={e => { e.preventDefault(); onClick(); }}
      disabled={disabled}
      className={`flex items-center justify-center w-7 h-7 rounded transition-colors ${
        active
          ? 'bg-brand-100 text-brand-700'
          : 'text-slate-600 hover:bg-slate-100 hover:text-slate-900'
      } disabled:opacity-30 disabled:cursor-not-allowed`}
    >
      {children}
    </button>
  );
}

function Divider() {
  return <span className="w-px h-5 bg-slate-200 mx-0.5 shrink-0" />;
}

// ── Colour picker ──────────────────────────────────────────────────────────────

const PALETTE = [
  '#0f172a', '#334155', '#64748b', '#94a3b8',
  '#dc2626', '#ea580c', '#d97706', '#16a34a',
  '#0891b2', '#2563eb', '#7c3aed', '#db2777',
];

function ColorPicker({ current, onChange }: { current: string; onChange: (c: string) => void }) {
  return (
    <div className="flex items-center gap-0.5 flex-wrap">
      {PALETTE.map(c => (
        <button
          key={c}
          type="button"
          title={c}
          onMouseDown={e => { e.preventDefault(); onChange(c); }}
          className={`w-4 h-4 rounded-sm border transition-transform hover:scale-110 ${
            current === c ? 'ring-2 ring-offset-1 ring-brand-500' : 'border-slate-200'
          }`}
          style={{ background: c }}
        />
      ))}
      <button
        type="button"
        title="Remove colour"
        onMouseDown={e => { e.preventDefault(); onChange(''); }}
        className="w-4 h-4 rounded-sm border border-slate-200 text-slate-400 text-[9px] leading-none hover:bg-slate-100 flex items-center justify-center"
      >
        ✕
      </button>
    </div>
  );
}

// ── Props ──────────────────────────────────────────────────────────────────────

export interface RichTextEditorProps {
  value: string;
  onChange: (html: string) => void;
  variables?: string[];
  placeholder?: string;
  minHeight?: number;
  label?: React.ReactNode;
  helper?: string;
}

// ── Editor ─────────────────────────────────────────────────────────────────────

export function RichTextEditor({
  value,
  onChange,
  variables = [],
  placeholder = 'Write your email content here…',
  minHeight = 320,
  label,
  helper,
}: RichTextEditorProps) {
  const editor = useEditor({
    extensions: [
      StarterKit.configure({ heading: { levels: [2, 3] } }),
      Underline,
      TextStyle,
      Color,
      TextAlign.configure({ types: ['heading', 'paragraph'] }),
      Link.configure({ openOnClick: false, HTMLAttributes: { class: 'text-blue-600 underline' } }),
      Image.configure({ HTMLAttributes: { style: 'max-width:100%;height:auto;' } }),
      Placeholder.configure({ placeholder }),
    ],
    content: value,
    onUpdate: ({ editor }) => onChange(editor.getHTML()),
    editorProps: {
      attributes: {
        class: 'prose prose-sm max-w-none focus:outline-none px-4 py-3 text-slate-800',
        style: `min-height:${minHeight}px`,
      },
    },
  });

  // Sync when parent pushes a new value (e.g. after save/refetch)
  useEffect(() => {
    if (!editor || editor.isDestroyed) return;
    if (editor.getHTML() !== value) {
      editor.commands.setContent(value ?? '', { emitUpdate: false });
    }
  }, [value, editor]);

  const insertVariable = useCallback((variable: string) => {
    editor?.chain().focus().insertContent(variable).run();
  }, [editor]);

  const setLink = useCallback(() => {
    const prev = editor?.getAttributes('link').href ?? '';
    const url = window.prompt('Enter URL (leave blank to remove link)', prev);
    if (url === null) return;
    if (url === '') { editor?.chain().focus().unsetLink().run(); return; }
    editor?.chain().focus().setLink({ href: url }).run();
  }, [editor]);

  const addImage = useCallback(() => {
    const url = window.prompt('Image URL');
    if (url) editor?.chain().focus().setImage({ src: url }).run();
  }, [editor]);

  if (!editor) return null;

  const currentColor = editor.getAttributes('textStyle').color ?? '';

  return (
    <div className="flex flex-col gap-1">
      {label && <label className="text-sm font-medium text-slate-700">{label}</label>}

      <div className="rounded-xl border border-slate-300 overflow-hidden focus-within:ring-2 focus-within:ring-brand-500 focus-within:border-brand-500 bg-white">

        {/* Toolbar */}
        <div className="flex flex-wrap items-center gap-0.5 px-2 py-1.5 border-b border-slate-200 bg-slate-50">

          <ToolBtn title="Undo" onClick={() => editor.chain().focus().undo().run()} disabled={!editor.can().undo()}>
            <Undo size={13} />
          </ToolBtn>
          <ToolBtn title="Redo" onClick={() => editor.chain().focus().redo().run()} disabled={!editor.can().redo()}>
            <Redo size={13} />
          </ToolBtn>

          <Divider />

          <ToolBtn title="Heading 2" active={editor.isActive('heading', { level: 2 })} onClick={() => editor.chain().focus().toggleHeading({ level: 2 }).run()}>
            <Heading2 size={13} />
          </ToolBtn>
          <ToolBtn title="Heading 3" active={editor.isActive('heading', { level: 3 })} onClick={() => editor.chain().focus().toggleHeading({ level: 3 }).run()}>
            <Heading3 size={13} />
          </ToolBtn>

          <Divider />

          <ToolBtn title="Bold" active={editor.isActive('bold')} onClick={() => editor.chain().focus().toggleBold().run()}>
            <Bold size={13} />
          </ToolBtn>
          <ToolBtn title="Italic" active={editor.isActive('italic')} onClick={() => editor.chain().focus().toggleItalic().run()}>
            <Italic size={13} />
          </ToolBtn>
          <ToolBtn title="Underline" active={editor.isActive('underline')} onClick={() => editor.chain().focus().toggleUnderline().run()}>
            <UnderlineIcon size={13} />
          </ToolBtn>

          <Divider />

          <ToolBtn title="Align left" active={editor.isActive({ textAlign: 'left' })} onClick={() => editor.chain().focus().setTextAlign('left').run()}>
            <AlignLeft size={13} />
          </ToolBtn>
          <ToolBtn title="Align center" active={editor.isActive({ textAlign: 'center' })} onClick={() => editor.chain().focus().setTextAlign('center').run()}>
            <AlignCenter size={13} />
          </ToolBtn>
          <ToolBtn title="Align right" active={editor.isActive({ textAlign: 'right' })} onClick={() => editor.chain().focus().setTextAlign('right').run()}>
            <AlignRight size={13} />
          </ToolBtn>

          <Divider />

          <ToolBtn title="Bullet list" active={editor.isActive('bulletList')} onClick={() => editor.chain().focus().toggleBulletList().run()}>
            <List size={13} />
          </ToolBtn>
          <ToolBtn title="Numbered list" active={editor.isActive('orderedList')} onClick={() => editor.chain().focus().toggleOrderedList().run()}>
            <ListOrdered size={13} />
          </ToolBtn>
          <ToolBtn title="Horizontal rule" onClick={() => editor.chain().focus().setHorizontalRule().run()}>
            <Minus size={13} />
          </ToolBtn>

          <Divider />

          <ToolBtn title="Add / edit link" active={editor.isActive('link')} onClick={setLink}>
            <LinkIcon size={13} />
          </ToolBtn>
          <ToolBtn title="Insert image from URL" onClick={addImage}>
            <ImageIcon size={13} />
          </ToolBtn>

          <Divider />

          <ColorPicker current={currentColor} onChange={c => {
            if (c) editor.chain().focus().setColor(c).run();
            else editor.chain().focus().unsetColor().run();
          }} />
        </div>

        {/* Variable insertion bar */}
        {variables.length > 0 && (
          <div className="flex flex-wrap items-center gap-1.5 px-3 py-2 bg-amber-50 border-b border-amber-100">
            <span className="text-xs text-amber-700 font-semibold shrink-0">Insert placeholder:</span>
            {variables.map(v => (
              <button
                key={v}
                type="button"
                title={`Click to insert ${v}`}
                onMouseDown={e => { e.preventDefault(); insertVariable(v); }}
                className="rounded bg-white border border-amber-300 px-1.5 py-0.5 text-xs font-mono text-amber-800 hover:bg-amber-100 transition-colors"
              >
                {v}
              </button>
            ))}
          </div>
        )}

        {/* Canvas */}
        <EditorContent editor={editor} />
      </div>
      {helper && (
        <p className="mt-1.5 text-xs text-slate-500">{helper}</p>
      )}
    </div>
  );
}
