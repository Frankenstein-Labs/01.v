# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecApplicationRecord, feature_category: :vulnerability_management do
  let_it_be(:project) { create(:project) }
  let(:db_ff_query) { "SELECT current_setting('vulnerability_management.dont_execute_db_trigger', true);" }

  describe '.feature_flagged_transaction_for' do
    it 'wraps the block in a transaction' do
      expect(described_class).to receive(:transaction).and_call_original

      described_class.feature_flagged_transaction_for(project) do
        # block content
      end
    end

    it 'calls pass_feature_flag_to_vuln_reads_db_trigger with the project' do
      expect(described_class).to receive(:pass_feature_flag_to_vuln_reads_db_trigger).with(project)

      described_class.feature_flagged_transaction_for(project) do
        # block content
      end
    end

    it 'yields the block' do
      block_executed = false

      described_class.feature_flagged_transaction_for(project) do
        block_executed = true
      end

      expect(block_executed).to be true
    end

    it 'returns the result of the block' do
      result = described_class.feature_flagged_transaction_for(project) do
        'test_result'
      end

      expect(result).to eq('test_result')
    end

    context 'when an exception occurs in the block' do
      it 'allows the transaction to rollback' do
        expect do
          described_class.feature_flagged_transaction_for(project) do
            raise StandardError, 'test error'
          end
        end.to raise_error(StandardError, 'test error')
      end
    end

    context 'when project is nil' do
      it 'passes nil to pass_feature_flag_to_vuln_reads_db_trigger' do
        expect(described_class).to receive(:pass_feature_flag_to_vuln_reads_db_trigger).with(nil)

        described_class.feature_flagged_transaction_for(nil) do
          # block content
        end
      end
    end
  end

  describe '.db_trigger_flag_not_set?' do
    context 'when the setting is not set (nil)' do
      # This test has a state leakage issue with the other tests in the file.
      # So we intentionally wipe the trigger value to prevent the leak. However
      # we cannot make Postgres treat the value as having never been set, only empty
      # so the method will return true for an empty string as well
      it 'returns true' do
        described_class.transaction do
          described_class.connection.execute("SELECT set_config(
            'vulnerability_management.dont_execute_db_trigger', NULL, true);")

          expect(described_class.db_trigger_flag_not_set?).to be true
        end
      end
    end

    context 'when the setting is set to a value' do
      it 'returns false when setting is "false"' do
        described_class.feature_flagged_transaction_for(nil) do
          expect(described_class.db_trigger_flag_not_set?).to be false
        end
      end

      it 'returns false when setting is "true"' do
        described_class.transaction do
          described_class.connection.execute(
            "SELECT set_config('vulnerability_management.dont_execute_db_trigger', 'true', true);"
          )

          expect(described_class.db_trigger_flag_not_set?).to be false
        end
      end
    end

    context 'when the setting is set to a non-empty value' do
      it 'returns false when result is not empty' do
        described_class.transaction do
          described_class.connection.execute(
            "SELECT set_config('vulnerability_management.dont_execute_db_trigger', 'some_value', true);"
          )

          expect(described_class.db_trigger_flag_not_set?).to be false
        end
      end
    end
  end

  describe '.pass_feature_flag_to_vuln_reads_db_trigger' do
    context 'when project is provided' do
      it 'sets the database configuration to true' do
        described_class.feature_flagged_transaction_for(project) do
          expect(described_class.connection.execute(db_ff_query).first['current_setting']).to eq 'true'
        end
      end

      it 'checks the feature flag with the correct project' do
        stub_feature_flags(turn_off_vulnerability_read_create_db_trigger_function: project)
        allow(Feature).to receive(:enabled?).and_call_original
        expect(Feature).to receive(:enabled?).with(:turn_off_vulnerability_read_create_db_trigger_function,
          project).and_return(false)

        described_class.feature_flagged_transaction_for(project) do
          expect(described_class.connection.execute(db_ff_query).first['current_setting']).to eq 'false'
        end
      end

      context 'when projects is an array with multiple projects' do
        it 'checks the feature flag for all projects' do
          project2 = create(:project)
          projects = [project, project2]

          stub_feature_flags(turn_off_vulnerability_read_create_db_trigger_function: project)
          allow(Feature).to receive(:enabled?).and_call_original

          expect(Feature).to receive(:enabled?).with(:turn_off_vulnerability_read_create_db_trigger_function,
            project).and_return(true)
          expect(Feature).to receive(:enabled?).with(:turn_off_vulnerability_read_create_db_trigger_function,
            project2).and_return(false)

          described_class.feature_flagged_transaction_for(projects) do
            # When all? returns false, feature_enabled should be false
            expect(described_class.connection.execute(db_ff_query).first['current_setting']).to eq 'false'
          end
        end
      end
    end

    context 'when project is nil' do
      context 'when feature flag is enabled for instance' do
        it 'sets the database configuration to true' do
          stub_feature_flags(turn_off_vulnerability_read_create_db_trigger_function: true)
          allow(Feature).to receive(:enabled?).and_call_original

          expect(Feature).to receive(:enabled?).with(:turn_off_vulnerability_read_create_db_trigger_function,
            :instance).and_call_original

          described_class.feature_flagged_transaction_for(nil) do
            expect(described_class.connection.execute(db_ff_query).first['current_setting']).to eq 'true'
          end
        end
      end

      context 'when feature flag is disabled for instance' do
        before do
          stub_feature_flags(turn_off_vulnerability_read_create_db_trigger_function: false)
        end

        it 'sets the database configuration to false' do
          described_class.feature_flagged_transaction_for(nil) do
            expect(described_class.connection.execute(db_ff_query).first['current_setting']).to eq 'false'
          end
        end
      end
    end

    context 'when called outside of a transaction' do
      it 'raises an error when transaction is not open' do
        # Mock transaction_open? to return false
        allow(described_class.connection).to receive(:transaction_open?).and_return(false)

        expect do
          described_class.pass_feature_flag_to_vuln_reads_db_trigger(project)
        end.to raise_error(StandardError,
          'pass_feature_flag_to_vuln_reads_db_trigger must be called within a transaction')
      end
    end
  end
end
