# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ServiceAccountMemberRemoveService, feature_category: :duo_agent_platform do
  let_it_be(:current_user) { create(:user) }
  let_it_be(:service_account) { create(:user) }
  let_it_be_with_reload(:group) { create(:group) }
  let_it_be_with_reload(:project) { create(:project, namespace: group) }

  let(:container) { project }
  let(:service) { described_class.new(current_user, container, service_account) }

  describe '#execute' do
    shared_examples 'successful service account removal' do
      it 'removes the service account membership' do
        expect { service.execute }.to change { container.members.count }.by(-1)
        expect(container.members.find_by(user_id: service_account.id)).to be_nil
      end

      it 'returns a success response' do
        expect(service.execute).to be_success
      end

      it 'calls destroy service with correct parameters' do
        member = container.member(service_account)
        expect_next_instance_of(
          Members::DestroyService,
          member,
          current_user: current_user,
          **destroy_service_options
        ) do |destroy_service|
          expect(destroy_service).to receive(:execute)
        end

        service.execute
      end
    end

    shared_examples 'no membership found' do
      it 'does not remove any membership' do
        expect { service.execute }.not_to change { container.members.count }
      end

      it 'returns a success response' do
        expect(service.execute).to be_success
      end
    end

    context 'with project container' do
      let(:container) { project }

      context 'when service account is not a member' do
        it_behaves_like 'no membership found'
      end

      context 'when service account is a member of the project' do
        before_all { project.add_developer(service_account) }

        it_behaves_like 'successful service account removal'
      end
    end

    context 'with group container' do
      let(:container) { group }

      context 'when service account is a direct member of the group' do
        before_all { group.add_developer(service_account) }

        it_behaves_like 'successful service account removal'
      end

      context 'when service account is not a direct member of the group' do
        context 'and has no project memberships within the group' do
          it_behaves_like 'no membership found'
        end

        context 'when service account is a member of a project within the group' do
          before_all { project.add_developer(service_account) }

          it 'removes project membership' do
            expect { service.execute }.to change { project.members.count }.by(-1)
            expect { service.execute }.not_to change { group.members.count }
            expect(project.members.find_by(user_id: service_account.id)).to be_nil
          end

          it 'returns a success response' do
            expect(service.execute).to be_success
          end
        end
      end
    end
  end

  private

  def destroy_service_options
    {
      skip_authorization: true
    }
  end
end
