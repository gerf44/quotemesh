import type { ReactNode } from "react";

export function Metric({
  label,
  value,
  note,
}: {
  label: string;
  value: string;
  note?: string;
}) {
  return (
    <article className="metric">
      <span>{label}</span>
      <strong>{value}</strong>
      {note && <small>{note}</small>}
    </article>
  );
}

export function EmptyState({
  title,
  copy,
  action,
}: {
  title: string;
  copy: string;
  action?: ReactNode;
}) {
  return (
    <div className="empty-state">
      <span className="empty-mark">QM</span>
      <div>
        <strong>{title}</strong>
        <p>{copy}</p>
      </div>
      {action}
    </div>
  );
}

export function StatusPill({
  children,
  tone = "neutral",
}: {
  children: ReactNode;
  tone?: "neutral" | "positive" | "warning";
}) {
  return <span className={`status-pill ${tone}`}>{children}</span>;
}
