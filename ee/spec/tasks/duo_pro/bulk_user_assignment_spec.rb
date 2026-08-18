# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'duo_pro:bulk_user_assignment', feature_category: :'add-on_provisioning' do
  let(:csv_file_path) { 'spec/fixtures/gitlab_subscriptions/duo/bulk_user_assignment.csv' }

  before do
    Rake.application.rake_require('tasks/duo_pro/bulk_user_assignment')
  end

  describe 'duo_pro:bulk_user_assignment task' do
    context 'when file_path/DUO_PRO_BULK_USER_FILE_PATH is not provided' do
      it 'raises an error' do
        expect do
          run_rake_task('duo_pro:bulk_user_assignment')
        end.to raise_error(RuntimeError, /File path is not provided/)
      end
    end

    context 'when Duo Pro AddOn purchase is not found' do
      it 'raises an error for missing Duo Pro AddOn purchase' do
        expected_error_message = "Unable to find Duo Pro AddOn purchase."

        expect { run_rake_task('duo_pro:bulk_user_assignment', csv_file_path) }
          .to raise_error(RuntimeError)
          .with_message(a_string_including(expected_error_message))
      end
    end

    context 'when Duo Pro AddOn purchase is found' do
      let(:add_on) { create(:gitlab_subscription_add_on) }

      before do
        add_on_purchase = create(:gitlab_subscription_add_on_purchase, :self_managed, quantity: 10, add_on: add_on)
        allow_next_instance_of(
          GitlabSubscriptions::Duo::BulkUserAssignment,
          %w[user1 user2 user3],
          add_on_purchase
        ) do |instance|
          response = { successful_assignments: ['success'], failed_assignments: ['Failed'] }
          allow(instance).to receive(:execute).and_return(response)
        end
      end

      it 'outputs success and failed assignments' do
        expected_output = "\nSuccessful Assignments:\nsuccess\n" \
                          "\nFailed Assignments:\nFailed\n"

        expect { run_rake_task('duo_pro:bulk_user_assignment', csv_file_path) }
          .to output(a_string_including(expected_output)).to_stdout
      end

      context 'with an env variable' do
        it 'outputs success and failed assignments' do
          stub_env('DUO_PRO_BULK_USER_FILE_PATH' => csv_file_path)
          expected_output = "\nSuccessful Assignments:\nsuccess\n" \
                            "\nFailed Assignments:\nFailed\n"

          expect { run_rake_task('duo_pro:bulk_user_assignment') }
            .to output(a_string_including(expected_output)).to_stdout
        end
      end
    end
  end
end
