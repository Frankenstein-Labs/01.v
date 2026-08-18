# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'geo:tools rake tasks', feature_category: :geo_replication do
  include RakeHelpers

  before_all do
    Rake.application.rake_require 'tasks/geo/tools'
    Rake::Task.define_task(:gitlab_environment)
  end

  describe 'geo:tools:cleanup_check' do
    it 'checks the whole catalog when no key is given' do
      expect(Gitlab::Geo::Tools).to receive(:cleanup_check).with(nil, min_retry_count: nil)

      run_rake_task('geo:tools:cleanup_check')
    end

    it 'checks a single error when a key is given' do
      known_error = instance_double(Geo::Tools::KnownError)
      allow(Geo::Tools::KnownErrors).to receive(:find)
        .with('file_missing_on_primary', min_retry_count: nil).and_return(known_error)

      expect(Gitlab::Geo::Tools).to receive(:cleanup_check).with(known_error, min_retry_count: nil)

      run_rake_task('geo:tools:cleanup_check', 'file_missing_on_primary')
    end

    it 'aborts for an unknown key' do
      expect(Gitlab::Geo::Tools).not_to receive(:cleanup_check)

      expect { run_rake_task('geo:tools:cleanup_check', 'nope') }
        .to raise_error(SystemExit, /Unknown error key: nope/)
    end

    it 'passes MIN_RETRY_COUNT as an integer' do
      stub_env('MIN_RETRY_COUNT', '3')

      expect(Gitlab::Geo::Tools).to receive(:cleanup_check).with(nil, min_retry_count: 3)

      run_rake_task('geo:tools:cleanup_check')
    end
  end

  describe 'geo:tools:resolve' do
    let(:known_error) { instance_double(Geo::Tools::KnownError) }

    before do
      allow(Geo::Tools::KnownErrors).to receive(:find)
        .with('url_blocked', any_args).and_return(known_error)
    end

    it 'finds the error and delegates to the module, dry run by default' do
      expect(Gitlab::Geo::Tools).to receive(:resolve).with(known_error, dry_run: true, limit: nil)

      run_rake_task('geo:tools:resolve', 'url_blocked')
    end

    it 'passes dry_run: false when DRY_RUN=false' do
      stub_env('DRY_RUN', 'false')

      expect(Gitlab::Geo::Tools).to receive(:resolve).with(known_error, dry_run: false, limit: nil)

      run_rake_task('geo:tools:resolve', 'url_blocked')
    end

    it 'passes LIMIT as an integer' do
      stub_env('LIMIT', '10')

      expect(Gitlab::Geo::Tools).to receive(:resolve).with(known_error, dry_run: true, limit: 10)

      run_rake_task('geo:tools:resolve', 'url_blocked')
    end

    it 'aborts when LIMIT is not a number' do
      stub_env('LIMIT', 'abc')

      expect(Gitlab::Geo::Tools).not_to receive(:resolve)

      expect { run_rake_task('geo:tools:resolve', 'url_blocked') }
        .to raise_error(SystemExit, /LIMIT must be a positive integer/)
    end

    it 'aborts when LIMIT is zero' do
      stub_env('LIMIT', '0')

      expect(Gitlab::Geo::Tools).not_to receive(:resolve)

      expect { run_rake_task('geo:tools:resolve', 'url_blocked') }
        .to raise_error(SystemExit, /LIMIT must be a positive integer/)
    end

    it 'aborts when LIMIT is negative' do
      stub_env('LIMIT', '-5')

      expect(Gitlab::Geo::Tools).not_to receive(:resolve)

      expect { run_rake_task('geo:tools:resolve', 'url_blocked') }
        .to raise_error(SystemExit, /LIMIT must be a positive integer/)
    end

    it 'passes MIN_RETRY_COUNT through to the resolution' do
      stub_env('MIN_RETRY_COUNT', '7')

      expect(Geo::Tools::KnownErrors).to receive(:find)
        .with('url_blocked', min_retry_count: 7, recovery_dump_dir: nil).and_return(known_error)
      expect(Gitlab::Geo::Tools).to receive(:resolve).with(known_error, dry_run: true, limit: nil)

      run_rake_task('geo:tools:resolve', 'url_blocked')
    end

    # 0 is the operator's way to ask for no retry-count gate, so it must survive validation.
    it 'accepts MIN_RETRY_COUNT=0' do
      stub_env('MIN_RETRY_COUNT', '0')

      expect(Geo::Tools::KnownErrors).to receive(:find)
        .with('url_blocked', min_retry_count: 0, recovery_dump_dir: nil).and_return(known_error)
      expect(Gitlab::Geo::Tools).to receive(:resolve).with(known_error, dry_run: true, limit: nil)

      run_rake_task('geo:tools:resolve', 'url_blocked')
    end

    it 'passes RECOVERY_DUMP_DIR through to the resolution' do
      stub_env('RECOVERY_DUMP_DIR', '/var/tmp/geo')

      expect(Geo::Tools::KnownErrors).to receive(:find)
        .with('url_blocked', min_retry_count: nil, recovery_dump_dir: '/var/tmp/geo')
        .and_return(known_error)
      expect(Gitlab::Geo::Tools).to receive(:resolve).with(known_error, dry_run: true, limit: nil)

      run_rake_task('geo:tools:resolve', 'url_blocked')
    end

    it 'aborts when MIN_RETRY_COUNT is not a number' do
      stub_env('MIN_RETRY_COUNT', 'abc')

      expect(Gitlab::Geo::Tools).not_to receive(:resolve)

      expect { run_rake_task('geo:tools:resolve', 'url_blocked') }
        .to raise_error(SystemExit, /MIN_RETRY_COUNT must be a non-negative integer/)
    end

    it 'aborts when MIN_RETRY_COUNT is negative' do
      stub_env('MIN_RETRY_COUNT', '-1')

      expect(Gitlab::Geo::Tools).not_to receive(:resolve)

      expect { run_rake_task('geo:tools:resolve', 'url_blocked') }
        .to raise_error(SystemExit, /MIN_RETRY_COUNT must be a non-negative integer/)
    end

    context 'with an unknown key' do
      before do
        allow(Geo::Tools::KnownErrors).to receive(:find).with('nope', any_args).and_return(nil)
      end

      it 'aborts without calling the module' do
        expect(Gitlab::Geo::Tools).not_to receive(:resolve)

        expect { run_rake_task('geo:tools:resolve', 'nope') }
          .to raise_error(SystemExit, /Unknown error key/)
      end
    end
  end
end
