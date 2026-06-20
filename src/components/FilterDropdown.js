import { useEffect, useLayoutEffect, useRef, useState } from 'react';
import { createPortal } from 'react-dom';

// Renders into document.body so the panel can't be clipped by a scrollable
// (overflow-x: auto) pill row — the row's implicit overflow-y: auto would
// otherwise crop anything that pops out below it.
export default function FilterDropdown({ open, anchorRef, onClose, className = '', children }) {
  const panelRef = useRef(null);
  const [coords, setCoords] = useState(null);

  useLayoutEffect(() => {
    if (!open) { setCoords(null); return; }
    const update = () => {
      const rect = anchorRef.current?.getBoundingClientRect();
      if (rect) setCoords({ top: rect.bottom + 6, left: rect.left });
    };
    update();
    window.addEventListener('resize', update);
    window.addEventListener('scroll', update, true);
    return () => {
      window.removeEventListener('resize', update);
      window.removeEventListener('scroll', update, true);
    };
  }, [open, anchorRef]);

  useEffect(() => {
    if (!open) return;
    const handler = e => {
      if (anchorRef.current?.contains(e.target)) return;
      if (panelRef.current?.contains(e.target)) return;
      onClose();
    };
    const onKeyDown = e => { if (e.key === 'Escape') onClose(); };
    document.addEventListener('mousedown', handler);
    document.addEventListener('keydown', onKeyDown);
    return () => {
      document.removeEventListener('mousedown', handler);
      document.removeEventListener('keydown', onKeyDown);
    };
  }, [open, anchorRef, onClose]);

  if (!open || !coords) return null;

  return createPortal(
    <div ref={panelRef} className={className} style={{ position: 'fixed', top: coords.top, left: coords.left, zIndex: 1000 }}>
      {children}
    </div>,
    document.body
  );
}
