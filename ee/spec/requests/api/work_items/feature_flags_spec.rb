# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::WorkItems::FeatureFlags, feature_category: :portfolio_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :repository, :private, developers: user) }
  let_it_be(:work_item) { create(:work_item, :issue, project: project) }

  let_it_be(:feature_flag) { create(:operations_feature_flag, project: project, name: 'flag_a', active: true) }
  let_it_be(:other_feature_flag) do
    create(:operations_feature_flag, project: project, name: 'flag_b', active: false)
  end

  let_it_be(:feature_flag_issue) { create(:feature_flag_issue, feature_flag: feature_flag, issue: work_item) }
  let_it_be(:other_feature_flag_issue) do
    create(:feature_flag_issue, feature_flag: other_feature_flag, issue: work_item)
  end

  let(:expected_total) { 2 }
  let(:n_plus_one_threshold) { 0 }

  before do
    stub_feature_flags(work_item_rest_api: user)
  end

  def add_development_feature_record
    flag = create(:operations_feature_flag, project: project, name: "flag-#{SecureRandom.hex(4)}")
    create(:feature_flag_issue, feature_flag: flag, issue: work_item)
  end

  def add_flags_in_new_projects(count)
    count.times do
      flag = create(:operations_feature_flag, project: create(:project, :private, developers: user),
        name: "flag-#{SecureRandom.hex(4)}")
      create(:feature_flag_issue, feature_flag: flag, issue: work_item)
    end
  end

  shared_examples 'feature_flags endpoint' do
    it_behaves_like 'a work item development feature endpoint'

    it 'returns the feature flags associated with the work item' do
      get api(api_request_path, user)

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response.pluck('id')).to contain_exactly(feature_flag.id, other_feature_flag.id)
      expect(json_response).to all(include('id', 'name', 'active', 'path', 'reference'))
    end

    it 'orders feature flags by name so pagination is deterministic' do
      # Created last but sorts first, so a page built without ORDER BY name would not return it.
      create(:feature_flag_issue,
        issue: work_item,
        feature_flag: create(:operations_feature_flag, project: project, name: 'flag_000'))

      get api(api_request_path, user), params: { per_page: 1 }

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response.pluck('name')).to eq(['flag_000'])
    end

    it 'exposes the feature flag attributes' do
      get api(api_request_path, user)

      row = json_response.find { |r| r['id'] == feature_flag.id }
      expect(row).to include(
        'name' => 'flag_a',
        'active' => true,
        'reference' => feature_flag.to_reference
      )
      expect(row['path']).to eq(feature_flag.path)
    end

    it 'renders a flag from another project with its project path' do
      other_project = create(:project, :private, developers: user)
      other_flag = create(:operations_feature_flag, project: other_project, name: 'cross_project_flag')
      create(:feature_flag_issue, feature_flag: other_flag, issue: work_item)

      get api(api_request_path, user)

      row = json_response.find { |r| r['id'] == other_flag.id }
      expect(row['reference']).to eq("[feature_flag:#{other_project.full_path}/#{other_flag.iid}]")
    end
  end

  describe 'GET /projects/:id/-/work_items/:work_item_iid/feature_flags' do
    let(:api_request_path) { "/projects/#{project.id}/-/work_items/#{work_item.iid}/feature_flags" }

    it_behaves_like 'feature_flags endpoint'

    it_behaves_like 'authorizing granular token permissions', :read_work_item do
      let(:boundary_object) { project }
      let(:request) do
        get api(api_request_path, personal_access_token: pat)
      end
    end

    it 'returns not_found when the user cannot read the work item' do
      other_user = create(:user)

      get api(api_request_path, other_user)

      expect(response).to have_gitlab_http_status(:not_found)
    end

    it 'avoids N+1 queries as the flags span more projects',
      :request_store, :use_sql_query_cache, :aggregate_failures do
      add_flags_in_new_projects(2)

      # Warm up so first-request lazy writes do not skew the baseline.
      get api(api_request_path, user)

      control = ActiveRecord::QueryRecorder.new { get api(api_request_path, user) }

      add_flags_in_new_projects(2)

      expect { get api(api_request_path, user) }.not_to exceed_query_limit(control)
      expect(response).to have_gitlab_http_status(:ok)
    end

    it 'omits unreadable flags from both the page and X-Total', :aggregate_failures do
      hidden_project = create(:project, :private, developers: user)
      hidden_project.project_feature.update!(feature_flags_access_level: ProjectFeature::DISABLED)
      create(:feature_flag_issue,
        issue: work_item,
        feature_flag: create(:operations_feature_flag, project: hidden_project, name: 'hidden_flag'))

      get api(api_request_path, user)

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response.pluck('name')).to contain_exactly('flag_a', 'flag_b')
      expect(response.headers['X-Total']).to eq('2')
    end

    # Uses fresh (non-shared) records so toggling the project feature does not leak into other examples.
    it 'excludes feature flags the user cannot read' do
      unreadable_project = create(:project, :repository, :private, developers: user)
      unreadable_project.project_feature.update!(feature_flags_access_level: ProjectFeature::DISABLED)
      unreadable_work_item = create(:work_item, :issue, project: unreadable_project)
      unreadable_flag = create(:operations_feature_flag, project: unreadable_project)
      create(:feature_flag_issue, feature_flag: unreadable_flag, issue: unreadable_work_item)

      get api("/projects/#{unreadable_project.id}/-/work_items/#{unreadable_work_item.iid}/feature_flags", user)

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response).to be_empty
    end
  end

  describe 'GET /namespaces/:id/-/work_items/:work_item_iid/feature_flags' do
    let(:api_request_path) do
      "/namespaces/#{CGI.escape(project.project_namespace.full_path)}/-/work_items" \
        "/#{work_item.iid}/feature_flags"
    end

    it_behaves_like 'feature_flags endpoint'

    it_behaves_like 'authorizing granular token permissions', :read_work_item do
      let(:boundary_object) { project }
      let(:request) do
        get api(api_request_path, personal_access_token: pat)
      end
    end
  end

  describe 'GET /groups/:id/-/work_items/:work_item_iid/feature_flags' do
    let_it_be(:group) { create(:group, :private, reporters: user) }
    let_it_be(:group_work_item) { create(:work_item, :epic, namespace: group) }

    let(:api_request_path) { "/groups/#{group.id}/-/work_items/#{group_work_item.iid}/feature_flags" }

    before do
      stub_licensed_features(epics: true)
    end

    it_behaves_like 'a group-level work item development feature endpoint returning empty'
  end
end
