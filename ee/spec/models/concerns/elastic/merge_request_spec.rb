# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequest, :elastic, feature_category: :global_search do
  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
  end

  let(:admin) { create(:user, :admin) }

  it_behaves_like 'limited indexing is enabled' do
    let_it_be(:object) { create :merge_request, source_project: project }
  end

  it 'searches merge requests', :sidekiq_inline, :enable_admin_mode do
    project = create(:project, :public, :repository)

    create :merge_request, title: 'bla-bla term1', source_project: project
    create :merge_request, description: 'term2 in description', source_project: project, target_branch: "feature2"
    create :merge_request, source_project: project, target_branch: "feature3"

    # The merge request you have no access to except as an administrator
    create :merge_request, title: 'also with term3', source_project: create(:project, :private)

    ensure_elasticsearch_index!

    options = { project_ids: [project.id], search_level: 'global' }

    expect(described_class.elastic_search('term1 | term2 | term3', options: options).total_count).to eq(2)
    expect(described_class.elastic_search(described_class.last.to_reference, options: options).total_count).to eq(1)
    expect(described_class.elastic_search('term3', options: options).total_count).to eq(0)

    options = { current_user: admin, search_level: 'global', project_ids: :any, public_and_internal_projects: true }
    expect(described_class.elastic_search('term3', options: options).total_count).to eq(1)
  end

  it 'names elasticsearch queries' do
    described_class.elastic_search('*', options: { search_level: 'global' }).total_count

    assert_named_queries('merge_request:match:search_terms')
  end

  describe 'json' do
    let_it_be(:label) { create(:label) }
    let_it_be_with_reload(:merge_request) { create(:labeled_merge_request, :with_assignee, labels: [label]) }

    let(:expected_hash) do
      merge_request.attributes.extract!(
        'id',
        'iid',
        'target_branch',
        'source_branch',
        'title',
        'description',
        'created_at',
        'updated_at',
        'state',
        'merge_status',
        'source_project_id',
        'target_project_id',
        'author_id'
      ).merge(
        'traversal_ids' => "#{merge_request.project.namespace.id}-p#{merge_request.project.id}-",
        'state' => merge_request.state,
        'type' => merge_request.es_type,
        'merge_requests_access_level' => ProjectFeature::ENABLED,
        'visibility_level' => Gitlab::VisibilityLevel::INTERNAL,
        'project_id' => merge_request.target_project.id,
        'hidden' => merge_request.author.banned?,
        'archived' => merge_request.target_project.archived?,
        'schema_version' => Elastic::Latest::MergeRequestInstanceProxy::SCHEMA_VERSION,
        'hashed_root_namespace_id' => merge_request.target_project.namespace.hashed_root_namespace_id,
        'label_ids' => [label.id.to_s],
        'assignee_ids' => merge_request.assignee_ids.map(&:to_s)
      )
    end

    before do
      merge_request.project.update!(visibility_level: Gitlab::VisibilityLevel::INTERNAL)
    end

    it 'returns json with all needed elements' do
      expect(merge_request.__elasticsearch__.as_indexed_json).to eq(expected_hash)
    end
  end

  it 'handles when a project is missing project_feature' do
    merge_request = create :merge_request
    allow(merge_request.project).to receive(:project_feature).and_return(nil)

    expect { merge_request.__elasticsearch__.as_indexed_json }.not_to raise_error
    expect(merge_request.__elasticsearch__.as_indexed_json['merge_requests_access_level'])
      .to eq(ProjectFeature::PRIVATE)
  end

  it_behaves_like 'no results when the user cannot read cross project' do
    let(:record1) { create(:merge_request, source_project: project, title: 'test-mr') }
    let(:record2) { create(:merge_request, source_project: project2, title: 'test-mr') }
  end
end
