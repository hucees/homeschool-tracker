import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Homeschool Tracker",
  description: "Permanent homeschool curriculum and student record system",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
