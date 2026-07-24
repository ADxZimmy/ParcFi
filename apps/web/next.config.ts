import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  transpilePackages: ["@parcfi/shared"],
  eslint: {
    // Linting runs as its own CI step (`npm run lint`); keep builds deterministic.
    ignoreDuringBuilds: true,
  },
};

export default nextConfig;
