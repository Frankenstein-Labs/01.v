# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::OrchestrationConfigurationRemoveBotWorker, feature_category: :security_policy_management do
  describe '#perform' do
    let_it_be(:project) { create(:project) }
    let_it_be(:user) { create(:user) }

    let(:current_user_id) { user.id }

    subject(:run_worker) { described_class.new.perform(project_id, current_user_id) }

    before_all do
      project.add_owner(user)
    end

    shared_examples_for 'worker exits without error' do
      it 'does not call the users destroy service' do
        expect(Users::DestroyService).not_to receive(:new)

        run_worker
      end

      it 'exits without error' do
        expect { run_worker }.not_to raise_error
      end
    end

    context 'with invalid project_id' do
      let(:project_id) { non_existing_record_id }

      it_behaves_like 'worker exits without error'
    end

    context 'with valid project_id' do
      let(:project_id) { project.id }

      context 'when user with given current_user_id does not exist' do
        let(:current_user_id) { non_existing_record_id }

        it_behaves_like 'worker exits without error'
      end

      context 'when current user is provided' do
        let(:current_user_id) { user.id }

        context 'when there is no security policy bot user' do
          it_behaves_like 'worker exits without error'
        end

        context 'with security policy bot user' do
          let_it_be(:security_policy_bot) { create(:user, :security_policy_bot) }

          before_all do
            project.add_guest(security_policy_bot)
          end

          it 'calls the users destroy service to carry out the deletion' do
            expect_next_instance_of(Users::DestroyService) do |service|
              expect(service).to receive(:execute).with(security_policy_bot, hard_delete: false,
                skip_authorization: true)
            end

            run_worker
          end

          it 'removes the bot together with its membership' do
            expect { run_worker }.to change { project.security_policy_bot }.to(nil)
              .and(change { project.member(security_policy_bot) }.to(nil))
          end

          context 'when the project is still linked to other security policies' do
            let_it_be(:security_orchestration_policy_configuration) do
              create(:security_orchestration_policy_configuration, project: project)
            end

            it_behaves_like 'worker exits without error'
          end
        end
      end
    end
  end
end
