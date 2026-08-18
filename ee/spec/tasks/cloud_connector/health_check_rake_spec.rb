# frozen_string_literal: true

require 'spec_helper'
require_relative '../../services/cloud_connector/status_checks/probes/test_probe'

RSpec.describe 'cloud_connector:health_check', :silence_stdout, feature_category: :duo_setting do
  let(:test_probe) { CloudConnector::StatusChecks::Probes::TestProbe.new(success: success) }
  let(:filename) { 'output.txt' }
  let(:filepath) { File.join(Tasks::CloudConnector::TaskHelper::OUTPUT_DIR, filename) }
  let(:user) { create(:user, username: 'test_user') }
  let(:success) { true }

  before do
    Rake.application.rake_require('ee/lib/tasks/cloud_connector/health_check', [Rails.root.to_s])
    allow_next_instance_of(::CloudConnector::StatusChecks::StatusService) do |status_service|
      allow(status_service).to receive(:probes).and_return([test_probe])
    end

    # Stub out all attempts to go to the filesystem.
    allow(File).to receive(:open).and_return(instance_double(File).as_null_object)
  end

  describe 'health check execution' do
    it 'executes the health check with TestProbe' do
      expect { run_rake_task('cloud_connector:health_check') }.to output(/Success: OK/).to_stdout
    end

    context 'when the probe fails' do
      let(:success) { false }

      it 'prints failure messages' do
        expect { run_rake_task('cloud_connector:health_check') }.to output(/Failure: NOK/).to_stdout
      end
    end
  end

  describe 'handling parameters' do
    context 'when include_details is true' do
      it 'prints probe details' do
        expect { run_rake_task('cloud_connector:health_check', [nil, nil, 'true']) }
          .to output(/"test": "true"/).to_stdout
      end
    end

    context 'when include_details is not provided' do
      it 'defaults to printing probe details' do
        expect { run_rake_task('cloud_connector:health_check', [nil, nil, nil]) }
          .to output(/"test": "true"/).to_stdout
      end
    end

    context 'when filename is provided' do
      it 'saves report to a file' do
        expect(File).to receive(:open).with(filepath, 'w')

        expect { run_rake_task('cloud_connector:health_check', [nil, filename]) }
          .to output(/Saving report to #{filepath}/).to_stdout
      end
    end

    context 'when filename is not provided' do
      it 'does not attempt to save the report to a file' do
        expect(File).not_to receive(:open)

        expect { run_rake_task('cloud_connector:health_check', [nil, nil]) }
          .to output(/✔ Success: OK/).to_stdout
      end
    end

    context 'when a username is provided' do
      it 'loads the user and uses it in the health check' do
        expect(User).to receive(:find_by_username).with('test_user').and_return(user)

        expect { run_rake_task('cloud_connector:health_check', ['test_user', nil]) }
          .to output(/✔ Success:/).to_stdout
      end

      it 'prints a warning if the user is not found and proceeds without the user' do
        expect { run_rake_task('cloud_connector:health_check', ['unknown_user', nil]) }
          .to output(/Warning: User 'unknown_user' not found. Proceeding without a user.../).to_stdout
      end
    end

    context 'when a username is not provided' do
      it 'executes the health check without a user' do
        expect(User).not_to receive(:find_by_username)

        expect { run_rake_task('cloud_connector:health_check', [nil, nil]) }
          .to output(/✔ Success: OK/).to_stdout
      end
    end
  end

  describe 'error handling' do
    it 'handles file write errors gracefully' do
      expect(File).to receive(:open).with(filepath, 'w').and_raise(StandardError.new('disk full'))

      expect { run_rake_task('cloud_connector:health_check', [nil, filename]) }
        .to output(/Failed to write report to #{filepath}: disk full/).to_stdout
    end
  end
end
