# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::GroupsController, :enable_admin_mode, feature_category: :groups_and_projects do
  let_it_be(:admin) { create(:admin) }

  before do
    sign_in(admin)
  end

  describe 'GET #index' do
    it 'pushes gitlabComSubscriptions SaaS feature to the frontend' do
      get admin_groups_path

      expect(response.body).to have_pushed_saas_features(gitlabComSubscriptions: false)
    end
  end
end
