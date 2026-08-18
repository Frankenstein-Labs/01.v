# Frontend Islands

This directory contains isolated frontend applications that are built and deployed independently.

## Structure

- `apps/` - Individual frontend applications
- `packages/configs/` - Shared configuration packages (ESLint, Prettier, TypeScript, etc.)

## Development

### Adding a New App

When you add a new app to the `apps/` directory:

1. Ensure your app has both `lint` and `test` scripts in its `package.json`
2. Update the CI configuration to include your app:
   ```bash
   # Preview changes without modifying files
   ruby scripts/update_fe_islands_ci.rb --dry-run

   # Apply changes
   ruby scripts/update_fe_islands_ci.rb
   ```

This will automatically update the `.gitlab/ci/static-analysis.gitlab-ci.yml` file to include your new app in the parallel ESLint jobs.

**Important**: The validation happens at multiple stages:

- **Local (pre-push hook)**: If you have lefthook installed, the validation runs automatically before you push, catching issues immediately
- **CI Pipeline**: The `validate-fe-islands-ci` job runs in CI to ensure the configuration is correct

If validation fails at either stage, you'll see a clear error message telling you to run the update script.

### Linting

Each app should have its own linting configuration and scripts. The CI will automatically run linting on all apps in parallel.

To run linting locally on a specific app:
```bash
cd apps/my_new_app
yarn lint
```

To run linting on all apps:
```bash
yarn workspaces run lint
```

## CI Configuration

### How CI Automation Works

The Frontend Islands CI configuration uses an automated discovery and validation system to ensure all CI jobs run on all apps without requiring manual updates to the CI YAML files.

#### CI Jobs

Frontend Islands uses an optimized approach with **Single Source of Truth (SSOT)** for parallelization: **one compilation job** for all apps, then **parallel test/lint/type-check jobs** per app.

**Parallelization Pattern**: The `.fe-islands-parallel` template in `.gitlab/ci/frontend.gitlab-ci.yml` defines the `FE_APP_DIR` matrix. All parallelized jobs extend this template and automatically inherit the matrix - ensuring all jobs stay synchronized.

1. **`.fe-islands-parallel`** - SSOT template for parallelization
   - Located in `.gitlab/ci/frontend.gitlab-ci.yml`
   - Defines `parallel.matrix.FE_APP_DIR` array once
   - All parallelized FE islands jobs extend this template
   - Update scripts modify this template; all jobs inherit changes automatically

1. **`compile-fe-islands`** - Builds all apps at once (NOT parallelized)
   - Located in `.gitlab/ci/frontend.gitlab-ci.yml`
   - Runs `scripts/build_frontend_islands` which executes `yarn build:prod`
   - Builds all apps in a single job (efficient - no redundant builds)
   - Saves artifacts for all apps: `ee/frontend_islands/apps/*/dist/*.js`
   - **Why not parallelized?** The build script builds all apps at once via the monorepo. Running it multiple times would waste resources.

1. **`test-fe-islands`** - Runs tests on each app in parallel
   - Located in `.gitlab/ci/frontend.gitlab-ci.yml`
   - Extends `.fe-islands-parallel` to inherit matrix parallelization
   - Each job runs `yarn test` for its specific app
   - Collects coverage reports and test results per app

1. **`type-check-fe-islands`** - Runs type checking on each app in parallel
   - Located in `.gitlab/ci/setup.gitlab-ci.yml`
   - Extends `.fe-islands-parallel` to inherit matrix parallelization
   - Each job runs `yarn lint:types` for its specific app
   - Validates TypeScript types per app

1. **`.eslint:fe-islands`** - Runs ESLint on each app in parallel
   - Located in `.gitlab/ci/static-analysis.gitlab-ci.yml`
   - Template that extends `.fe-islands-parallel` to inherit matrix parallelization
   - Each job runs `yarn lint` for its specific app
   - Provides per-app linting results

1. **`validate-fe-islands-ci`** - Validates CI configuration matches actual apps
   - Located in `.gitlab/ci/setup.gitlab-ci.yml`
   - Automatically discovers apps in `ee/frontend_islands/apps/`
   - Validates `.fe-islands-parallel` template matrix matches actual apps
   - Verifies all expected jobs correctly extend the SSOT template
   - Note: Does NOT validate `compile-fe-islands` (intentionally not parallelized)
   - Fails the pipeline if configuration is out of sync
   - Provides clear error messages with remediation steps

#### Local Validation (Lefthook)

The validation also runs locally via lefthook's pre-push hook:

- **Hook**: `validate-fe-islands-ci` in `lefthook.yml`
- **Trigger**: Runs when you push changes to `ee/frontend_islands/apps/`, `.gitlab/ci/static-analysis.gitlab-ci.yml`, or `.gitlab/ci/frontend.gitlab-ci.yml`
- **Benefit**: Catches configuration issues before they reach CI, saving time and resources
- **Setup**: Lefthook should be installed automatically in GitLab development environments

#### Automation Scripts

All scripts use shared functionality from `scripts/fe_islands_ci_shared.rb` which centralizes the SSOT pattern and common logic.

**`scripts/update_fe_islands_ci.rb`** - Updates CI configuration

- Discovers all app directories in `ee/frontend_islands/apps/`
- Validates each app has required scripts: `lint`, `lint:types`, `test`, `build`
- Warns about apps missing required scripts
- **Updates ONLY the `.fe-islands-parallel` template** in `.gitlab/ci/frontend.gitlab-ci.yml`
- All jobs that extend the template automatically inherit the updated matrix
- Simpler than before: one template update instead of updating multiple jobs
- Supports `--dry-run` flag to preview changes

**`scripts/validate_fe_islands_ci.rb`** - Validates CI configuration (STRICT)

- Runs during CI pipeline and locally via lefthook
- **FAILS if any app lacks valid `package.json` with required scripts: `lint`, `lint:types`, `test`, `build`**
- Extracts matrix from `.fe-islands-parallel` SSOT template
- Verifies all expected jobs (`type-check-fe-islands`, `.eslint:fe-islands`, `test-fe-islands`) correctly extend the template
- Compares actual app directories against configured apps in template
- Note: Does NOT validate `compile-fe-islands` (intentionally builds all apps at once)
- Exits with error if:
  - Any app has missing or invalid scripts
  - Apps don't match template configuration
  - Jobs don't properly extend the SSOT template
- Provides detailed error messages showing exactly what's wrong and how to fix it

**`scripts/fe_islands_ci_shared.rb`** - Shared functionality

- Centralizes SSOT template configuration
- Provides common methods for app discovery, validation, and CI parsing
- Defines which jobs should extend the template
- See inline documentation for extension points

#### Extending the Automation System

The automation system uses a **Single Source of Truth (SSOT) pattern** centralized in `scripts/fe_islands_ci_shared.rb`. All parallelized jobs extend the `.fe-islands-parallel` template and automatically inherit the matrix.

**To add a new required script** (e.g., `format`):

Modify the `REQUIRED_SCRIPTS` array in `scripts/fe_islands_ci_shared.rb`:

```ruby
REQUIRED_SCRIPTS = %w[lint lint:types test build format].freeze
```

Both validation and update scripts will automatically enforce this requirement for all apps.

**To add a new parallel job** (much simpler with SSOT!):

1. Add the job to the appropriate CI YAML file and make it **extend `.fe-islands-parallel`**:

   ```yaml
   my-new-fe-islands-job:
     extends:
       - .some-base-template
       - .fe-islands-parallel  # Inherits matrix automatically!
     script:
       - cd ee/frontend_islands/apps/${FE_APP_DIR}
       - yarn run my-command
   ```

1. Add the job to the `JOBS_EXTENDING_TEMPLATE` array in `scripts/fe_islands_ci_shared.rb`:

   ```ruby
   JOBS_EXTENDING_TEMPLATE = [
     { name: 'type-check-fe-islands', file: SETUP_CI_FILE },
     { name: '.eslint:fe-islands', file: STATIC_ANALYSIS_CI_FILE },
     { name: 'test-fe-islands', file: FRONTEND_CI_FILE },
     { name: 'my-new-fe-islands-job', file: FRONTEND_CI_FILE }
   ].freeze
   ```

1. Done! The job automatically:
   - Gets the `FE_APP_DIR` matrix from `.fe-islands-parallel` via template inheritance
   - Updates when you run the update script (updates happen via template, not per-job)
   - Is validated by the validation script (verifies template extension)

**To add jobs in a new CI file**:

1. Define a constant for the new CI file in `scripts/fe_islands_ci_shared.rb`
1. Add the job to `JOBS_EXTENDING_TEMPLATE` with the new file path
1. The scripts automatically verify template extension across all CI files

**Important**:
- All parallelized FE islands jobs MUST extend `.fe-islands-parallel`
- Jobs that process all apps at once (like `compile-fe-islands`) should NOT extend the template
- The validation script will fail if jobs don't properly extend the SSOT template

See `scripts/fe_islands_ci_shared.rb` for detailed inline documentation and examples.

#### App Requirements (STRICT)

**All apps in `ee/frontend_islands/apps/` MUST meet these requirements:**

1. Be a directory under `ee/frontend_islands/apps/`
1. Contain a valid `package.json` file
1. Have all required scripts defined in `package.json`: `lint`, `lint:types`, `test`, `build`

**Strict enforcement**: The validation will **FAIL** if any app directory exists without meeting all requirements. This ensures:
- CI jobs like `compile-fe-islands` won't fail due to invalid apps
- A consistent pattern across all Frontend Islands apps
- Early detection of incomplete or misconfigured apps

If you're working on a new app that's not ready yet, keep it outside the `apps/` directory until it's complete.

#### Workflow Example

When you add a new app called `my_new_app`:

1. **Create the app directory**: `ee/frontend_islands/apps/my_new_app/`
1. **Add a `package.json` file** with required scripts: `lint`, `lint:types`, `test`, `build`
1. **Commit your changes**
1. **Try to push** - Lefthook validation catches the issue:

   ```text
   ✗ Frontend Islands CI configuration is out of sync!

   Missing in CI configuration:
     - my_new_app

   To fix this, run:
     ruby scripts/update_fe_islands_ci.rb
   ```

1. **Run the update script** locally:

   ```bash
   ruby scripts/update_fe_islands_ci.rb
   ```

1. **Commit the updated CI file**
1. **Push successfully** - your changes include the updated CI configuration
1. **CI passes** - your app is now included in parallel ESLint checks

This multi-layered validation (local + CI) ensures developers never forget to update the CI configuration when adding new apps.
