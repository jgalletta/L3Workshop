import { Link } from 'react-router';
import { Button } from '@/components/ui/button';

export default function NotFound() {
  return (
    <div className="mx-auto max-w-3xl px-4 py-24 text-center sm:px-6 lg:px-8">
      <p className="text-sm font-semibold uppercase tracking-widest text-dmv-blue">
        Page not found
      </p>
      <h1 className="mt-3 text-5xl font-bold tracking-tight text-dmv-navy">
        404
      </h1>
      <p className="mx-auto mt-4 max-w-md text-base text-dmv-slate">
        We couldn't find the page you're looking for. It may have moved, or the
        link may be out of date.
      </p>
      <div className="mt-8 flex justify-center">
        <Button asChild size="lg">
          <Link to="/">Return to Home</Link>
        </Button>
      </div>
    </div>
  );
}
