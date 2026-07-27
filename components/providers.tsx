"use client";

import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { useState, type ReactNode } from "react";
import { WagmiProvider, createConfig, http } from "wagmi";
import { injected } from "wagmi/connectors";
import { ARC } from "@/lib/network";
import { publicConfig } from "@/lib/deployment";

const config = createConfig({
  chains: [ARC.chain],
  connectors: [injected()],
  transports: { [ARC.chain.id]: http(publicConfig.rpcUrl) },
  ssr: true,
});

export function Providers({ children }: { children: ReactNode }) {
  const [queryClient] = useState(() => new QueryClient());
  return (
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>
    </WagmiProvider>
  );
}
