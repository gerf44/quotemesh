import Link from "next/link";

export function Brand() {
  return (
    <Link href="/" className="brand" aria-label="QuoteMesh home">
      <svg viewBox="0 0 40 40" aria-hidden="true">
        <rect x="2" y="2" width="36" height="36" rx="10" />
        <path d="M10 14h11a6 6 0 0 1 0 12H10" />
        <path d="M16 10v20M26 12v16" />
      </svg>
      <span>
        <strong>QuoteMesh</strong>
        <small>Built on Arc</small>
      </span>
    </Link>
  );
}
