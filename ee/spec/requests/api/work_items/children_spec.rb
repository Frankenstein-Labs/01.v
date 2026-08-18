# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::WorkItems::Children, feature_category: :portfolio_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, :private, reporters: user) }
  let_it_be(:project) { create(:project, :private, group: group, reporters: user) }
  let_it_be(:parent_work_item) { create(:work_item, :epic, namespace: group) }
  let_it_be(:child_work_item) { create(:work_item, :issue, project: project) }

  before_all do
    create(:parent_link, work_item: child_work_item, work_item_parent: parent_work_item)
  end

  before do
    stub_feature_flags(work_item_rest_api: true)
    stub_licensed_features(epics: true, subepics: true)
  end

  describe 'GET /groups/:id/-/work_items/:work_item_iid/children' do
    let(:api_request_path) { "/groups/#{group.id}/-/work_items/#{parent_work_item.iid}/children" }

    it 'returns the children of the parent work item' do
      get api(api_request_path, user)

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response.pluck('id')).to contain_exactly(child_work_item.id)
    end

    it_behaves_like 'authorizing granular token permissions', :read_work_item do
      let(:boundary_object) { group }
      let(:request) do
        get api(api_request_path, personal_access_token: pat)
      end
    end

    context 'without the epics license' do
      before do
        stub_licensed_features(epics: false)
      end

      it 'returns 404 when the parent is not readable' do
        get api(api_request_path, user)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'with children across multiple projects in nested groups' do
      let_it_be(:subgroup_a) { create(:group, :private, parent: group, reporters: user) }
      let_it_be(:subgroup_b) { create(:group, :private, parent: group, reporters: user) }

      let_it_be(:project_a) { create(:project, :private, group: subgroup_a, reporters: user) }
      let_it_be(:project_b) { create(:project, :private, group: subgroup_b, reporters: user) }
      let_it_be(:project_a_child) { create(:work_item, :issue, project: project_a) }
      let_it_be(:project_b_child) { create(:work_item, :issue, project: project_b) }

      let_it_be(:other_root_group) { create(:group, :private) }
      let_it_be(:hidden_project) { create(:project, :private, group: other_root_group) }
      let_it_be(:hidden_child) { create(:work_item, :issue, project: hidden_project) }

      before_all do
        create(:parent_link, work_item: project_a_child, work_item_parent: parent_work_item, relative_position: 100)
        create(:parent_link, work_item: project_b_child, work_item_parent: parent_work_item, relative_position: 200)
        create(:parent_link, work_item: hidden_child, work_item_parent: parent_work_item, relative_position: 300)
      end

      it 'returns readable cross-project children and omits the unreadable one' do
        get api(api_request_path, user)

        expect(response).to have_gitlab_http_status(:ok)
        ids = json_response.pluck('id')
        expect(ids).to include(project_a_child.id, project_b_child.id, child_work_item.id)
        expect(ids).not_to include(hidden_child.id)
      end
    end
  end

  describe 'POST /groups/:id/-/work_items/:work_item_iid/children/:child_id' do
    let_it_be_with_reload(:child) { create(:work_item, :issue, project: project) }
    let_it_be(:unauthorized_user) { create(:user, guest_of: group) }
    let(:already_attached_child) { child_work_item }
    let(:other_parent_work_item) { create(:work_item, :epic, namespace: group) }
    let(:invalid_hierarchy_child_work_item) { create(:work_item, :task, project: project) }
    let(:confidential_parent_work_item) { create(:work_item, :epic, :confidential, namespace: group) }

    let(:cross_boundary_child_work_item) do
      other_project = create(:project, :private, group: group, reporters: user)
      create(:work_item, :issue, project: other_project)
    end

    let(:unreadable_child_work_item) do
      other_group = create(:group, :private)
      other_project = create(:project, :private, group: other_group)
      create(:work_item, :issue, project: other_project)
    end

    let(:path_for) do
      ->(work_item_iid:, child_id:) { "/groups/#{group.id}/-/work_items/#{work_item_iid}/children/#{child_id}" }
    end

    it_behaves_like 'authorizing granular token permissions', :update_work_item, expected_success_status: :created do
      let(:boundary_object) { group }
      let(:api_request_path) { path_for.call(work_item_iid: parent_work_item.iid, child_id: child.id) }
      let(:request) do
        post api(api_request_path, personal_access_token: pat)
      end
    end

    it_behaves_like 'attach child work item endpoint'
  end
end
