# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ProjectTrackedContextPolicy, feature_category: :vulnerability_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }
  let_it_be(:tracked_context) do
    create(:security_project_tracked_context, project: project)
  end

  subject(:policy) { described_class.new(user, tracked_context) }

  describe 'delegation' do
    it 'delegates to the project policy' do
      delegated_policies = policy.delegated_policies.values

      expect(delegated_policies).to include(
        an_object_having_attributes(
          user: user,
          subject: project
        )
      )
    end
  end

  describe 'permissions' do
    context 'when user has project access' do
      before_all do
        project.add_developer(user)
      end

      it 'allows project-level permissions' do
        expect(policy).to be_allowed(:read_project)
        expect(policy).to be_allowed(:push_code)
      end
    end

    context 'when user has no project access' do
      it 'denies project-level permissions' do
        expect(policy).to be_disallowed(:read_project)
        expect(policy).to be_disallowed(:push_code)
      end
    end

    context 'when user is admin' do
      let(:user) { create(:admin) }

      context 'when admin mode is enabled', :enable_admin_mode do
        it 'allows admin permissions' do
          expect(policy).to be_allowed(:read_project)
        end
      end

      context 'when admin mode is disabled' do
        it 'denies admin permissions' do
          expect(policy).to be_disallowed(:read_project)
        end
      end
    end
  end
end
