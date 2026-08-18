# frozen_string_literal: true

require 'spec_helper'
require 'rainbow'

RSpec.describe Tasks::CloudConnector::TaskHelper, :silence_stdout, feature_category: :duo_setting do
  let(:filename) { 'output.txt' }
  let(:filepath) { File.join(described_class::OUTPUT_DIR, filename) }
  let!(:user) { create(:user, username: 'test_user') }
  let(:success) { true }
  let(:message) { 'OK' }
  let(:details) { { test: 'true' } }
  let(:errors) { [] }
  let(:probe_results) do
    [
      instance_double(CloudConnector::StatusChecks::Probes::ProbeResult,
        name: 'test_probe',
        success?: success,
        message: message,
        details: details,
        errors: errors)
    ]
  end

  describe '.find_user' do
    it 'finds the user by username' do
      expect(User).to receive(:find_by_username).with('test_user').and_call_original

      expect(described_class.find_user('test_user')).to eq(user)
    end

    it 'prints a warning and returns nil if the username is not provided' do
      expect { described_class.find_user(nil) }
        .to output(/Warning: The username was not provided. Proceeding without a user/).to_stdout
    end

    it 'prints a warning and returns nil if the user is not found' do
      allow(User).to receive(:find_by_username).with('unknown_user').and_call_original

      expect { described_class.find_user('unknown_user') }
        .to output(/Warning: User 'unknown_user' not found. Proceeding without a user/).to_stdout
    end
  end

  describe '.save_report' do
    it 'prints a warning if filename is not provided' do
      expect { described_class.save_report(nil, probe_results) }
        .to output(/If you want to save report to a file/).to_stdout
    end

    it 'saves the report to a file' do
      expect(File).to receive(:open).with(filepath, 'w').and_yield(StringIO.new)

      expect { described_class.save_report(filename, probe_results) }
        .to output(/Saving report to #{filepath}/).to_stdout
    end

    it 'handles file write errors gracefully' do
      allow(File).to receive(:open).and_raise(StandardError.new('disk full'))

      expect { described_class.save_report(filename, probe_results) }
        .to output(/Failed to write report to #{filepath}: disk full/).to_stdout
    end
  end

  describe '.process_probe_results' do
    context 'when probe succeeds' do
      it 'prints success message' do
        expect { described_class.process_probe_results(probe_results) }
          .to output(/Success: OK/).to_stdout
      end
    end

    context 'when probe fails' do
      let(:success) { false }
      let(:message) { 'NOK' }
      let(:errors) { ActiveModel::Errors.new(nil) }

      it 'prints failure messages' do
        errors.add(:base, 'Something went wrong')

        expect { described_class.process_probe_results(probe_results) }
          .to output(/Failure: Something went wrong/).to_stdout
      end

      context 'when no errors' do
        it 'prints failure messages' do
          expect { described_class.process_probe_results(probe_results) }
            .to output(/Failure: NOK/).to_stdout
        end
      end

      context 'when the error is "User is not provided"' do
        let(:success) { false }
        let(:message) { 'NOK' }

        it 'prints skipping message' do
          errors.add(:base, described_class::USER_NOT_PROVIDED_MESSAGE)

          expect { described_class.process_probe_results(probe_results) }
            .to output(/Skipping Test probe check: User not provided/).to_stdout
        end
      end
    end

    context 'when include_details is true' do
      it 'prints probe details' do
        expect { described_class.process_probe_results(probe_results, include_details: true) }
          .to output(/"test": "true"/).to_stdout
      end
    end

    context 'when include_details is false' do
      it 'does not print probe details' do
        expect { described_class.process_probe_results(probe_results, include_details: false) }
          .not_to output(/"test": "true"/).to_stdout
      end
    end
  end
end
