# Automated Follow-Up

## Running the Demo Locally

### Prerequisites

- Ruby `3.4.9`
- Bundler
- SQLite
- Git

### Setup

From the project directory:

```bash
git clone <repository-url>
cd automated-follow-up

bin/setup --skip-server
bin/rails db:seed
bin/dev
```

`bin/dev` starts the three required processes:

- Rails web server
- Tailwind CSS watcher
- Background job worker

Open the demo at:

```text
http://localhost:3000
```

The background worker must be running because event ingestion and cadence sweeps run asynchronously.

### Watching the jobs

The **Jobs** link in the header opens the Mission Control dashboard at
`http://localhost:3000/jobs`: queues, workers and their heartbeats, finished and failed jobs with
their arguments, and a **Run now** button for the recurring cadence sweep. It is the fastest way to
see whether a sweep actually ran and what it was handed.

The dashboard is open with no login. It is bundled for development only, so it is absent from any
other environment rather than sitting there unauthenticated, and this app has no user model to
authenticate it against.

## Demo Flow

1. Open the **Triage** page.
2. Click **Reset demo**.
3. Click **Advance 1 day** or **Ingest next event**.
4. Refresh the page after the worker processes the job.
5. Review the triage results and generated drafts.
6. Open **Drafts**.
7. Approve or deny a draft.
8. Click **Advance 4 days** to make the next cadence step eligible.
9. Run another cycle and review the next draft.

The demo uses simulated time, so no real waiting is required.

## Resetting the Demo

To reset only the demo state:

```bash
bin/rails db:seed
```

To completely reset the local database:

```bash
bin/setup --reset
bin/dev
```

If drafts do not appear after clicking a control, confirm that the `jobs: bin/jobs` process is still running.
