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

### Intial thoughts when reading the assignment

Of the top of my head I jotted things down and just spoke out loud some of my initial thoughts when reading the assignment. I was already familiar with building out some form of automated messaging system based on a 'policy' so I knew what kind of domain concepts and language that would be introduced. I naturally leaned towards a relational db and some web framework with strong CRUD capabilities and chose Ruby on Rails. At first I was not thinking about rails because with the seed file given I thought this would only be an event-processing system. Ultimately I still chose Rails with relational db because there were stateful business rules that needed to be modeled out and entities that naturally needed some relationship with other entities. This allowed me to spin up the demo pretty quickly with AI.

### Where I stopped...
I stopped at covering the 


### Scalability
> what changes when this runs for a parent company with 50 shops, each with their own quotes, phone numbers, and opinions about what "follow up" means?

I built this demo with scalability and multi-tenancy in mind so it is already structures so we can introduce a parent hiearchy to represent this. If `Account` represents each shop then we would need some parent model which can be called `Organization` to represent the parent company. Each account will have their own opinion on what 'follow up' means and thats fine because the `Cadence` will capture the rules and business logic on what 'follow up' is. An `Organization` can still introduce a default Cadence but the child accounts should be able to override it.

**NOTE** my demo does not display multi-tenancy

```
Organization (parent company) -> Account (shop) -> Cadence -> quotes,phone numbers,etc
```
This also means that each event, background job, quote, customers, etc will always be account scoped because the biggest thing we do not want is one technician or cutomer from one company affecting reports/analytics and workflow for another company. 

### This is what I would build with another day ...

1. Make `Cadence::Step` configurable and move all triage rules and step configs to the `Cadence` model(this is the parent model that should hold all these business rules). That way if there was ever another account needed or another HVAC business that wants to be part of this system we can just update their associated `Cadence` with their unique business rules.
