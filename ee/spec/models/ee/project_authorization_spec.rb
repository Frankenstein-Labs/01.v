# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProjectAuthorization, feature_category: :groups_and_projects do
  describe 'scopes' do
    describe '.eligible_approvers_by_project_id_and_access_levels' do
      let_it_be(:guest) { create(:user) }
      let_it_be(:developer) { create(:user) }
      let_it_be(:maintainer) { create(:user) }
      let_it_be(:project) { create(:project, guests: guest, developers: developer, maintainers: maintainer) }
      let(:access_levels) { [::Gitlab::Access::DEVELOPER, ::Gitlab::Access::MAINTAINER] }

      subject(:approver_ids) do
        described_class
          .eligible_approvers_by_project_id_and_access_levels([project], access_levels)
          .pluck_user_ids
      end

      it 'returns users with sufficient project access level' do
        expect(approver_ids).to contain_exactly(developer.id, maintainer.id)
      end
    end
  end

  describe '.visible_to_user_and_access_level' do
    let_it_be(:user) { create(:user) }
    let_it_be(:project1) { create(:project) }
    let_it_be(:project2) { create(:project) }
    let_it_be(:developer_auth) { described_class.create!(user: user, project: project2, access_level: Gitlab::Access::DEVELOPER) }
    let_it_be(:maintainer_auth) { described_class.create!(user: user, project: project1, access_level: Gitlab::Access::MAINTAINER) }

    it 'returns the records for given user that have at least the given access' do
      authorizations = described_class.visible_to_user_and_access_level(user, Gitlab::Access::MAINTAINER)

      expect(authorizations.count).to eq(1)
      expect(authorizations[0].user_id).to eq(maintainer_auth.user_id)
      expect(authorizations[0].project_id).to eq(maintainer_auth.project_id)
      expect(authorizations[0].access_level).to eq(maintainer_auth.access_level)
    end
  end
end
