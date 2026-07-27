import type { ReactNode } from "react";

export function PageShell({
  eyebrow,
  title,
  copy,
  actions,
  children,
}: {
  eyebrow: string;
  title: string;
  copy: string;
  actions?: ReactNode;
  children: ReactNode;
}) {
  return (
    <main className="page-shell">
      <section className="page-intro">
        <div>
          <p className="eyebrow">{eyebrow}</p>
          <h1>{title}</h1>
          <p>{copy}</p>
        </div>
        {actions}
      </section>
      {children}
    </main>
  );
}
