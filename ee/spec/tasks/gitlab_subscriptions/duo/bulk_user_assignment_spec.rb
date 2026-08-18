# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'gitlab_subscriptions:duo:bulk_user_assignment', :silence_stdout,
  feature_category: :'add-on_provisioning' do
  let(:csv_file_path) { 'spec/fixtures/gitlab_subscriptions/duo/bulk_user_assignment.csv' }
  let(:task) { 'gitlab_subscriptions:duo:bulk_user_assignment' }
  let(:invalid_file_path_error) { 'File path is invalid' }

  let(:assignments_output) do
    <<~OUTPUT.strip
      Successful Assignments:
      success

      Failed Assignments:
      failed
    OUTPUT
  end

  let(:stub_bulk_assignment) do
    allow_next_instance_of(
      GitlabSubscriptions::Duo::BulkUserAssignment,
      %w[user1 user2 user3],
      add_on_purchase
    ) do |instance|
      response = { successful_assignments: ['success'], failed_assignments: ['failed'] }
      allow(instance).to receive(:execute).and_return(response)
    end
  end

  before do
    Rake.application.rake_require('tasks/gitlab_subscriptions/duo/bulk_user_assignment')
  end

  describe 'duo:bulk_user_assignment task' do
    shared_examples 'invalid file path error' do
      it 'raises an error for an invalid file path' do
        expect { run_rake_task(task) }.to raise_error(RuntimeError, /#{invalid_file_path_error}/)
      end
    end

    shared_examples 'missing Duo add-on purchase error' do
      it 'raises an error for missing Duo add-on purchase' do
        expect { run_rake_task(task, csv_file_path, namespace_id) }
          .to raise_error(RuntimeError, /Unable to find Duo add-on purchase/)
      end
    end

    shared_examples 'assignments output' do
      it 'outputs successful and failed assignments' do
        expect { run_rake_task(task, csv_file_path, namespace_id) }
          .to output(a_string_including(assignments_output)).to_stdout
      end
    end

    context 'when file_path is not provided' do
      it_behaves_like 'invalid file path error'
    end

    context 'when file_path is not found' do
      let(:invalid_file_path) { 'invalid/path/to/file.csv' }

      context 'when provided as argument' do
        it 'raises an invalid file path error' do
          expect { run_rake_task(task, invalid_file_path) }
            .to raise_error(RuntimeError, /#{invalid_file_path_error}/)
        end
      end

      context 'when provided as environment variable' do
        before do
          stub_env('DUO_BULK_USER_FILE_PATH', invalid_file_path)
        end

        it_behaves_like 'invalid file path error'
      end
    end

    context 'when GitLab.com', :saas do
      context 'when namespace_id is not provided' do
        it 'raises a missing namespace ID error' do
          expect { run_rake_task(task, csv_file_path) }
            .to raise_error(RuntimeError, /Namespace ID is not provided/)
        end
      end

      context 'when namespace_id is provided' do
        context 'when namespace is not found' do
          context 'when namespace_id is provided as an argument' do
            it 'raises an error for namespace not found' do
              expect { run_rake_task(task, csv_file_path, non_existing_record_id) }
                .to raise_error(RuntimeError, /Namespace not found/)
            end
          end

          context 'when namespace_id is provided as an environment variable' do
            before do
              stub_env('NAMESPACE_ID', non_existing_record_id)
            end

            it 'raises an error for namespace not found' do
              expect { run_rake_task(task, csv_file_path) }
                .to raise_error(RuntimeError, /Namespace not found/)
            end
          end
        end

        context 'when namespace is found' do
          let(:group) { create(:group) }
          let(:namespace_id) { group.id }

          before do
            stub_bulk_assignment
          end

          context 'with a GitLab.com Duo Enterprise add-on purchase' do
            let!(:add_on_purchase) do
              create(:gitlab_subscription_add_on_purchase, :duo_enterprise, namespace: group)
            end

            it_behaves_like 'assignments output'
          end

          context 'with a GitLab.com Duo Pro add-on purchase' do
            let!(:add_on_purchase) do
              create(:gitlab_subscription_add_on_purchase, :duo_pro, namespace: group)
            end

            it_behaves_like 'assignments output'
          end

          context 'with no Duo add-on purchase' do
            let(:add_on_purchase) { nil }

            it_behaves_like 'missing Duo add-on purchase error'
          end
        end
      end
    end

    context 'when Self-managed' do
      let(:namespace_id) { nil }

      before do
        stub_bulk_assignment
      end

      context 'with a Self-managed Duo Enterprise add-on purchase' do
        let!(:add_on_purchase) do
          create(:gitlab_subscription_add_on_purchase, :self_managed, :duo_enterprise)
        end

        it_behaves_like 'assignments output'
      end

      context 'with a Self-managed Duo Pro add-on purchase' do
        let!(:add_on_purchase) do
          create(:gitlab_subscription_add_on_purchase, :self_managed, :duo_pro)
        end

        it_behaves_like 'assignments output'
      end

      context 'with no Duo add-on purchase' do
        let(:add_on_purchase) { nil }

        it_behaves_like 'missing Duo add-on purchase error'
      end

      context 'with a GitLab.com Duo Enterprise add-on purchase' do
        let(:group) { create(:group) }
        let!(:add_on_purchase) do
          create(:gitlab_subscription_add_on_purchase, :duo_enterprise, namespace: group)
        end

        it_behaves_like 'missing Duo add-on purchase error'
      end
    end
  end
end
