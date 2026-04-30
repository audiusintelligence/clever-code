async function getHealth() {
  const apiUrl = process.env.NEXT_PUBLIC_API_URL || 'http://backend:8000';
  try {
    const res = await fetch(`${apiUrl}/health`, { cache: 'no-store' });
    return res.ok ? 'ok' : 'down';
  } catch {
    return 'down';
  }
}

export default async function HomePage() {
  const apiStatus = await getHealth();

  return (
    <main className="min-h-screen flex items-center justify-center p-8">
      <div className="max-w-2xl w-full bg-white rounded-2xl shadow-lg p-10">
        <h1 className="text-4xl font-bold text-audius-navy mb-2">
          __SOLUTION_NAME__
        </h1>
        <p className="text-gray-600 mb-8">__SOLUTION_DESCRIPTION__</p>

        <div className="space-y-3 border-t pt-6">
          <div className="flex justify-between text-sm">
            <span className="text-gray-500">Frontend</span>
            <span className="font-mono text-green-600">running</span>
          </div>
          <div className="flex justify-between text-sm">
            <span className="text-gray-500">Backend API</span>
            <span className={apiStatus === 'ok' ? 'font-mono text-green-600' : 'font-mono text-red-600'}>
              {apiStatus}
            </span>
          </div>
        </div>

        <div className="mt-8 pt-6 border-t text-xs text-gray-400">
          Clever Solution · audius-base template
        </div>
      </div>
    </main>
  );
}
