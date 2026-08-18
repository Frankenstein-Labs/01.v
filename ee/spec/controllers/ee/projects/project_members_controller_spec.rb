# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::ProjectMembersController, feature_category: :groups_and_projects do
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:project) { create(:project, :public, maintainers: user) }
  let_it_be_with_reload(:requester) { create(:project_member, :guest, project: project) }
  let_it_be_with_reload(:requester2) { create(:project_member, :guest, project: project) }

  let(:params) do
    {
      project_member: { access_level: Gitlab::Access::MAINTAINER },
      namespace_id: project.namespace,
      project_id: project,
      id: requester
    }
  end

  describe 'PUT update' do
    before do
      sign_in(user)
    end

    include_examples 'member promotion management'
  end
end
