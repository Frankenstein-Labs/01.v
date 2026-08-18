# frozen_string_literal: true

RSpec.shared_examples 'bot management worker examples' do
  describe '#perform' do
    let_it_be_with_reload(:namespace) { create(:group, :with_security_orchestration_policy_configuration) }
    let_it_be(:namespace_projects, freeze: false) { create_list(:project, 2, group: namespace) }
    let_it_be(:namespace_without_linked_policies, freeze: false) { create(:group) }
    let_it_be(:user, freeze: false) { create(:user) }
    let(:current_user_id) { nil }
    let(:namespace_project_ids) { namespace_projects.map(&:id) }

    subject(:run_worker) { described_class.new.perform(namespace_id, current_user_id) }

    before_all do
      namespace_projects.each do |project|
        project.add_owner(user)
      end
    end

    shared_examples_for 'worker exits without error' do
      it 'does not enqueues additional workers' do
        expect(management_worker).not_to receive(:bulk_perform_in_with_contexts)

        run_worker
      end

      it 'exits without error' do
        expect { run_worker }.not_to raise_error
      end
    end

    context 'with invalid namespace_id' do
      let(:namespace_id) { non_existing_record_id }

      it_behaves_like 'worker exits without error'
    end

    context 'with valid namespace_id' do
      let(:namespace_id) { namespace.id }

      context 'when user with given current_user_id does not exist' do
        let(:current_user_id) { non_existing_record_id }

        it_behaves_like 'worker exits without error'
      end

      context 'when current user is provided' do
        let(:current_user_id) { user.id }

        context 'when namespace does not have security orchestration configuration linked' do
          let(:namespace_id) { namespace_without_linked_policies.id }

          it_behaves_like 'worker exits without error'
        end

        it 'enqueues a worker for each projects', :aggregate_failures do
          expect(management_worker)
            .to receive(:bulk_perform_in_with_contexts)
                  .with(kind_of(Integer), match_array(namespace_project_ids),
                    { arguments_proc: kind_of(Proc), context_proc: kind_of(Proc) })

          run_worker
        end

        it_behaves_like 'an idempotent worker' do
          let(:job_args) { [namespace_id, current_user_id] }
        end
      end
    end
  end
end
