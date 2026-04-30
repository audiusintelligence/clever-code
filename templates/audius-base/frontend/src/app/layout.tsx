import './globals.css';

export const metadata = {
  title: '__SOLUTION_NAME__',
  description: '__SOLUTION_DESCRIPTION__',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="de">
      <body className="font-sans antialiased bg-gray-50 text-gray-900">
        {children}
      </body>
    </html>
  );
}
