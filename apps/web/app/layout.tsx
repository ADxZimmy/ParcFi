import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "ParcFi — release the clean lines",
  description:
    "Programmable settlement for freight-invoice exceptions: undisputed line items release immediately, only disputes stay in USDC escrow on Arc.",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
