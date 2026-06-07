import { useEffect, useRef, useState } from 'react';

export default function LazyImage({ src, eager = false, ...rest }) {
  const ref = useRef(null);
  const [show, setShow] = useState(eager);

  useEffect(() => {
    if (show) return;
    const el = ref.current;
    if (!el || typeof IntersectionObserver === 'undefined') { setShow(true); return; }
    const observer = new IntersectionObserver(
      entries => { if (entries.some(e => e.isIntersecting)) { setShow(true); observer.disconnect(); } },
      { rootMargin: '1500px 0px' }
    );
    observer.observe(el);
    return () => observer.disconnect();
  }, [show]);

  return <img ref={ref} src={show ? src : undefined} {...rest} />;
}
