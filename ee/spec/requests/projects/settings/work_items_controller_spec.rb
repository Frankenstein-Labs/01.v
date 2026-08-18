# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::Settings::WorkItemsController, feature_category: :team_planning do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:project) { create(:project, group: create(:group)) }
  let_it_be(:user, freeze: false) { create(:user) }

  before do
    sign_in(user)
  end

  shared_examples 'successful access' do
    it 'returns 200' do
      subject

      expect(response).to have_gitlab_http_status(:ok)
    end
  end

  shared_examples 'unauthorized access' do
    it 'returns 404' do
      subject

      expect(response).to have_gitlab_http_status(:not_found)
    end
  end

  shared_examples 'redirects to sign in' do
    it 'returns 302' do
      subject

      expect(response).to have_gitlab_http_status(:redirect)
    end
  end

  describe 'GET #show' do
    subject { get project_settings_work_items_path(project) }

    where(:user_role, :configurable_work_item_types_licensed, :expected_result) do
      :maintainer | true  | 'successful access'
      :maintainer | false | 'unauthorized access'
      :owner      | true  | 'successful access'
      :owner      | false | 'unauthorized access'

      :anonymous  | true  | 'redirects to sign in'
      :anonymous  | false | 'redirects to sign in'
      :guest      | true  | 'unauthorized access'
      :guest      | false | 'unauthorized access'
      :developer  | true  | 'unauthorized access'
      :developer  | false | 'unauthorized access'
    end

    with_them do
      before do
        assign_user_role(user, user_role, project)
        stub_licensed_features(configurable_work_item_types: configurable_work_item_types_licensed)
      end

      it_behaves_like params[:expected_result]
    end
  end

  def assign_user_role(user, user_role, project)
    case user_role
    when :anonymous then sign_out(user)
    when :guest then project.add_guest(user)
    when :developer then project.add_developer(user)
    when :maintainer then project.add_maintainer(user)
    when :owner then project.add_owner(user)
    end
  end
end
