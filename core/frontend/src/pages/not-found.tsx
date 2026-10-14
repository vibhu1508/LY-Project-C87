import { Link } from "react-router-dom";

export default function NotFound() {
  return (
    <div className="min-h-screen flex flex-col items-center justify-center px-6 text-center">
      <h1 className="text-5xl font-semibold text-foreground">404</h1>
      <p className="mt-3 text-sm text-muted-foreground">Page not found</p>
      <p className="mt-1 text-sm text-muted-foreground/80">
        The page you’re looking for doesn’t exist.
      </p>
      <Link
        to="/"
        className="mt-6 inline-flex items-center rounded-full glass glass-hover px-5 py-2 text-sm font-medium text-foreground"
      >
        Back to Home
      </Link>
    </div>
  );
}
