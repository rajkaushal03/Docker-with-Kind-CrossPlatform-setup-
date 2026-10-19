# Linkwise

Linkwise is a responsive bookmark dashboard built with React and Vite. It supports guest bookmarks saved in the current browser, Firebase email/password sign-in, page metadata fetching through Jina Reader, tag filters, grid/list views, and an optional server-backed AI summary flow.

## Run locally

```sh
npm install
npm run dev
```

Copy `.env.example` to `.env.local` and add the Firebase web app settings to enable account creation and sign-in. Enable the Email/Password provider in Firebase Authentication. Without Firebase settings, the dashboard remains available in guest mode and saves links in local browser storage.

## AI summaries

Set `VITE_SUMMARIZE_API_URL` to a server endpoint that accepts `POST` JSON in the form `{ "url": "...", "title": "..." }` and responds with `{ "summary": "..." }`. The endpoint should fetch/extract the page content and run the Genkit flow (which can use Jina Reader for page content). Keep provider credentials and model keys on the server; never expose them in `VITE_` variables.

For production, restrict the summary endpoint with rate limiting and validate requested URLs server-side. Configure Firebase Authentication and any database/storage security rules in the Firebase console before using this app with real accounts.
