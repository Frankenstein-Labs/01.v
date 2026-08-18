# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ExternalStatusChecks::CreateService, feature_category: :groups_and_projects do
  let_it_be_with_reload(:project) { create(:project) }
  let_it_be_with_reload(:protected_branch) { create(:protected_branch, project: project) }
  let_it_be(:maintainer) { create(:user, maintainer_of: project) }

  let(:user) { maintainer }
  let(:params) do
    {
      name: 'Test',
      external_url: 'https://external_url.text/hello.json',
      protected_branch_ids: [protected_branch.id],
      shared_secret: 'shared_secret'
    }
  end

  subject(:execute) { described_class.new(container: project, current_user: user, params: params).execute }

  it_behaves_like 'create external status services'
end
