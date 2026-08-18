# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::EnrollmentHelper, feature_category: :secrets_management do
  include described_class

  let(:group) { instance_double(Group, id: 7) }
  let(:project) { instance_double(Project, id: 11) }

  describe '#allow_secrets_manager_namespace_enrollment?' do
    it 'delegates to NamespaceEnrollment.enrollment_allowed?' do
      expect(SecretsManagement::NamespaceEnrollment).to receive(:enrollment_allowed?).with(group).and_return(:result)

      expect(allow_secrets_manager_namespace_enrollment?(group)).to eq(:result)
    end
  end

  describe '#allow_secrets_manager_instance_enrollment?' do
    it 'delegates to InstanceEnrollment.enrollment_allowed?' do
      expect(SecretsManagement::InstanceEnrollment).to receive(:enrollment_allowed?).and_return(:result)

      expect(allow_secrets_manager_instance_enrollment?).to eq(:result)
    end
  end

  describe '#secrets_manager_available_for_group?' do
    let(:user) { instance_double(User) }

    before do
      allow(self).to receive(:current_user).and_return(user)
    end

    context 'when Availability.for_group? is true and user can :read_secrets_manager' do
      it 'returns true' do
        allow(SecretsManagement::Availability).to receive(:for_group?).with(group).and_return(true)
        allow(self).to receive(:can?).with(user, :read_secrets_manager, group).and_return(true)

        expect(secrets_manager_available_for_group?(group)).to be true
      end
    end

    context 'when Availability.for_group? is false' do
      it 'returns false' do
        allow(SecretsManagement::Availability).to receive(:for_group?).with(group).and_return(false)

        expect(secrets_manager_available_for_group?(group)).to be false
      end
    end

    context 'when user cannot :read_secrets_manager' do
      it 'returns false' do
        allow(SecretsManagement::Availability).to receive(:for_group?).with(group).and_return(true)
        allow(self).to receive(:can?).with(user, :read_secrets_manager, group).and_return(false)

        expect(secrets_manager_available_for_group?(group)).to be false
      end
    end
  end

  describe '#secrets_manager_available_for_project?' do
    let(:user) { instance_double(User) }

    before do
      allow(self).to receive(:current_user).and_return(user)
    end

    context 'when Availability.for_project? is true and user can :read_project_secrets_manager' do
      it 'returns true' do
        allow(SecretsManagement::Availability).to receive(:for_project?).with(project).and_return(true)
        allow(self).to receive(:can?).with(user, :read_project_secrets_manager, project).and_return(true)

        expect(secrets_manager_available_for_project?(project)).to be true
      end
    end

    context 'when Availability.for_project? is false' do
      it 'returns false' do
        allow(SecretsManagement::Availability).to receive(:for_project?).with(project).and_return(false)

        expect(secrets_manager_available_for_project?(project)).to be false
      end
    end

    context 'when user cannot :read_project_secrets_manager' do
      it 'returns false' do
        allow(SecretsManagement::Availability).to receive(:for_project?).with(project).and_return(true)
        allow(self).to receive(:can?).with(user, :read_project_secrets_manager, project).and_return(false)

        expect(secrets_manager_available_for_project?(project)).to be false
      end
    end
  end

  describe '#secrets_manager_available_and_active_for_group?' do
    let(:group_secrets_manager) { instance_double(SecretsManagement::GroupSecretsManager, active?: active) }

    before do
      allow(SecretsManagement::Availability).to receive(:for_group?).with(group).and_return(true)
      allow(SecretsManagement::GroupSecretsManager).to receive(:find_by_group_id).with(group.id)
        .and_return(group_secrets_manager)
    end

    context 'when SM is available and active' do
      let(:active) { true }

      it 'returns true' do
        expect(secrets_manager_available_and_active_for_group?(group)).to be true
      end
    end

    context 'when SM is available but not active' do
      let(:active) { false }

      it 'returns false' do
        expect(secrets_manager_available_and_active_for_group?(group)).to be false
      end
    end

    context 'when SM is available but no group_secrets_manager record exists' do
      let(:group_secrets_manager) { nil }
      let(:active) { false }

      it 'returns falsey' do
        expect(secrets_manager_available_and_active_for_group?(group)).to be_falsey
      end
    end

    context 'when SM is not available' do
      let(:active) { true }

      before do
        allow(SecretsManagement::Availability).to receive(:for_group?).with(group).and_return(false)
      end

      it 'returns falsey' do
        expect(secrets_manager_available_and_active_for_group?(group)).to be_falsey
      end
    end
  end

  describe '#secrets_manager_available_and_active_for_project?' do
    let(:project_secrets_manager) { instance_double(SecretsManagement::ProjectSecretsManager, active?: active) }

    before do
      allow(SecretsManagement::Availability).to receive(:for_project?).with(project).and_return(true)
      allow(SecretsManagement::ProjectSecretsManager).to receive(:find_by_project_id).with(project.id)
        .and_return(project_secrets_manager)
    end

    context 'when SM is available and active' do
      let(:active) { true }

      it 'returns true' do
        expect(secrets_manager_available_and_active_for_project?(project)).to be true
      end
    end

    context 'when SM is available but not active' do
      let(:active) { false }

      it 'returns false' do
        expect(secrets_manager_available_and_active_for_project?(project)).to be false
      end
    end

    context 'when SM is available but no project_secrets_manager record exists' do
      let(:project_secrets_manager) { nil }
      let(:active) { false }

      it 'returns falsey' do
        expect(secrets_manager_available_and_active_for_project?(project)).to be_falsey
      end
    end

    context 'when SM is not available' do
      let(:active) { true }

      before do
        allow(SecretsManagement::Availability).to receive(:for_project?).with(project).and_return(false)
      end

      it 'returns falsey' do
        expect(secrets_manager_available_and_active_for_project?(project)).to be_falsey
      end
    end
  end
end
