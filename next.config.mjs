/** @type {import('next').NextConfig} */
const remotePatterns = [
  { protocol: "http", hostname: "localhost", port: "8080", pathname: "/uploads/**" },
  { protocol: "https", hostname: "**.up.railway.app", pathname: "/**" },
  { protocol: "https", hostname: "placehold.co" },
];

if (process.env.NEXT_PUBLIC_FILE_URL) {
  try {
    const parsed = new URL(process.env.NEXT_PUBLIC_FILE_URL);
    remotePatterns.push({
      protocol: parsed.protocol.replace(":", ""),
      hostname: parsed.hostname,
      port: parsed.port || undefined,
      pathname: "/**",
    });
  } catch {
    // Ignore invalid URL
  }
}

const nextConfig = {
  output: "standalone",
  reactStrictMode: true,
  images: {
    remotePatterns,
  },
  async rewrites() {
    // If BACKEND_URL is set, Next.js can proxy client requests to backend server-side
    if (process.env.BACKEND_URL) {
      return [
        {
          source: "/api/proxy/:path*",
          destination: `${process.env.BACKEND_URL}/api/v1/:path*`,
        },
      ];
    }
    return [];
  },
};

export default nextConfig;
