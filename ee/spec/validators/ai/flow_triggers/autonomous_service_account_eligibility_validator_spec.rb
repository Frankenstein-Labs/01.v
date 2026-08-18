# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::FlowTriggers::AutonomousServiceAccountEligibilityValidator, feature_category: :duo_agent_platform do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }

  subject(:validator) { described_class.new(service_account, project) }

  describe '#valid?' do
    context 'when service account is group-scoped, active, and a project member' do
      let_it_be(:service_account) do
        create(:service_account).tap do |sa|
          sa.user_detail.update!(provisioned_by_group_id: group.id)
          project.add_guest(sa)
        end
      end

      it { is_expected.to be_valid }
    end

    context 'when service account is project-scoped, active, and a project member' do
      let_it_be(:service_account) do
        create(:service_account).tap do |sa|
          sa.user_detail.update!(provisioned_by_project_id: project.id)
          project.add_guest(sa)
        end
      end

      it { is_expected.to be_valid }
    end

    context 'when user is not a service account' do
      let_it_be(:service_account) { create(:user, developer_of: project) }

      it 'is not valid' do
        expect(validator).not_to be_valid
        expect(validator.errors.full_messages).to include('User must be a service account')
      end
    end

    context 'when user is nil' do
      let(:service_account) { nil }

      it 'is not valid' do
        expect(validator).not_to be_valid
        expect(validator.errors.full_messages).to include('User must be a service account')
      end
    end

    context 'when service account is instance-wide (not scoped)' do
      let_it_be(:service_account) { create(:service_account, guest_of: project) }

      it 'is not valid' do
        expect(validator).not_to be_valid
        expect(validator.errors.full_messages).to include(
          'Service account must be group or project scoped, not instance-wide'
        )
      end
    end

    context 'when service account is blocked' do
      let_it_be(:service_account) do
        create(:service_account, :blocked).tap do |sa|
          sa.user_detail.update!(provisioned_by_group_id: group.id)
        end
      end

      it 'is not valid' do
        expect(validator).not_to be_valid
        expect(validator.errors.full_messages).to include('Service account must be active')
      end
    end

    context 'when service account is not a project member' do
      let_it_be(:service_account) do
        create(:service_account).tap do |sa|
          sa.user_detail.update!(provisioned_by_group_id: group.id)
        end
      end

      it 'is not valid' do
        expect(validator).not_to be_valid
        expect(validator.errors.full_messages).to include(
          'Service account must be a member of the target project'
        )
      end
    end

    context 'when multiple validations fail' do
      let_it_be(:service_account) { create(:service_account, :blocked) }

      it 'reports all failures' do
        expect(validator).not_to be_valid
        expect(validator.errors.full_messages).to include(
          'Service account must be group or project scoped, not instance-wide',
          'Service account must be active',
          'Service account must be a member of the target project'
        )
      end
    end
  end
end
