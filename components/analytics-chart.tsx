"use client";

import { Bar, BarChart, CartesianGrid, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts";

export function AnalyticsChart({ volume }: { volume: number }) {
  if (volume <= 0) return null;
  const data = [{ name: "All indexed time", volume }];
  return (
    <div style={{ width: "100%", height: 300 }} aria-label="Indexed settlement volume chart">
      <ResponsiveContainer>
        <BarChart data={data} margin={{ top: 20, right: 20, left: 10, bottom: 10 }}>
          <CartesianGrid stroke="#d8ddd5" vertical={false} />
          <XAxis dataKey="name" tick={{ fontSize: 12 }} />
          <YAxis tick={{ fontSize: 12 }} />
          <Tooltip />
          <Bar dataKey="volume" fill="#0b766e" radius={[5, 5, 0, 0]} />
        </BarChart>
      </ResponsiveContainer>
    </div>
  );
}
