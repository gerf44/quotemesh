import type { Metadata } from "next";
import { IBM_Plex_Mono, Manrope } from "next/font/google";
import { Providers } from "@/components/providers";
import { SiteHeader } from "@/components/site-header";
import "./globals.css";

const sans = Manrope({ subsets: ["latin"], variable: "--font-sans" });
const mono = IBM_Plex_Mono({
  subsets: ["latin"],
  weight: ["400", "500", "600"],
  variable: "--font-mono",
});

export const metadata: Metadata = {
  title: "QuoteMesh — Multi-provider stablecoin RFQ",
  description:
    "Independent multi-provider USDC/EURC RFQ marketplace built on Arc Network.",
  applicationName: "QuoteMesh",
  icons: {
    icon: "/icon.svg",
  },
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body className={`${sans.variable} ${mono.variable}`}>
        <Providers>
          <SiteHeader />
          {children}
          <footer>
            <div>
              <strong>QuoteMesh</strong>
              <span>Independent stablecoin RFQ infrastructure · Built on Arc</span>
            </div>
            <p>
              QuoteMesh is an independent application built on Arc Network. It is not an official
              Arc, Circle, or StableFX product. References to Arc and Circle infrastructure describe
              external technology used by the application and do not imply endorsement.
            </p>
          </footer>
        </Providers>
      </body>
    </html>
  );
}
