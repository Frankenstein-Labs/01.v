# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Organizations::Transfer::UsersService, :aggregate_failures, feature_category: :organization do
  let_it_be(:old_organization, freeze: false) { create(:organization) }
  let_it_be(:new_organization) { create(:organization) }
  let_it_be_with_refind(:group) { create(:group, organization: old_organization) }

  let(:users) { group.users_with_descendants }
  let(:service) { described_class.new(users: users, new_organization: new_organization) }

  describe '#execute', :eager_load do
    context 'with personal snippet repository states' do
      let_it_be_with_refind(:user1) { create(:user, organization: old_organization) }
      let_it_be_with_refind(:non_group_user) { create(:user, organization: old_organization) }
      let_it_be_with_refind(:personal_snippet) do
        create(:personal_snippet, author: user1, organization: old_organization)
      end

      let_it_be_with_refind(:non_group_snippet) do
        create(:personal_snippet, author: non_group_user, organization: old_organization)
      end

      before_all do
        group.add_developer(user1)
        Users::Internal.in_organization(old_organization).ghost
      end

      before do
        service.prepare_bots
      end

      it 'updates snippet_organization_id for personal snippet repository states of transferred users' do
        snippet_repo = create(:snippet_repository, snippet: personal_snippet)
        repository_state = create(:geo_snippet_repository_state, snippet_repository: snippet_repo)

        service.execute

        expect(repository_state.reload.snippet_organization_id).to eq(new_organization.id)
      end

      it 'does not update snippet repository states for users not in the group' do
        non_group_repo = create(:snippet_repository, snippet: non_group_snippet)
        non_group_state = create(:geo_snippet_repository_state, snippet_repository: non_group_repo)

        expect { service.execute }.not_to change { non_group_state.reload.snippet_organization_id }
      end
    end
  end
end
