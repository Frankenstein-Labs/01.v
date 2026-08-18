# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::GroupService, feature_category: :global_search do
  include SearchResultHelpers
  include ProjectHelpers
  include UserHelpers

  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:group) { create(:group) }
  let_it_be_with_refind(:project) { create(:project, :public, :repository, namespace: group) }

  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
  end

  it_behaves_like 'EE search service shared examples', ::Gitlab::GroupSearchResults,
    ::Search::Elastic::GroupSearchResults do
    let(:scope) { group }
    let(:service) { described_class.new(user, scope, params) }
  end

  describe '#search_type' do
    let(:service) { described_class.new(user, group, scope: scope) }

    subject(:search_type) { service.search_type }

    using RSpec::Parameterized::TableSyntax

    where(:use_zoekt, :use_elasticsearch, :scope, :elasticsearch_code_scope_setting, :expected_type) do
      true   | true  | 'blobs'  | false | 'zoekt'
      false  | true  | 'blobs'  | false | 'basic'
      false  | false | 'blobs'  | false | 'basic'
      true   | true  | 'issues' | false | 'advanced'
      true   | false | 'issues' | false | 'basic'
      true   | true  | 'blobs'  | true  | 'zoekt'
      false  | true  | 'blobs'  | true  | 'advanced'
      false  | false | 'blobs'  | true  | 'basic'
      true   | true  | 'issues' | true  | 'advanced'
      true   | false | 'issues' | true  | 'basic'
    end

    with_them do
      before do
        allow(service).to receive_messages(scope: scope, use_zoekt?: use_zoekt, use_elasticsearch?: use_elasticsearch)
        stub_ee_application_setting(elasticsearch_code_scope: elasticsearch_code_scope_setting)
      end

      it { is_expected.to eq(expected_type) }

      %w[basic advanced zoekt].each do |search_type|
        context "with search_type param #{search_type}" do
          let(:service) { described_class.new(user, group, { scope: scope, search_type: search_type }) }

          it { is_expected.to eq(search_type) }
        end
      end
    end
  end

  describe 'group search', :elastic do
    let(:results) { described_class.new(user, search_group, search: term).execute }

    context 'for projects scope' do
      let_it_be(:term) { "RandomName" }
      let_it_be(:nested_group) { create(:group, :nested) }

      # These projects shouldn't be found
      let_it_be(:outside_project) { create(:project, :public, name: "Outside #{term}") }
      let_it_be(:private_project) do
        create(:project, :private, namespace: nested_group, name: "Private #{term}")
      end

      let_it_be(:other_project) { create(:project, :public, namespace: nested_group, name: 'OtherProject') }

      # These projects should be found
      let_it_be(:internal_project_1) do
        create(:project, :internal, namespace: nested_group, name: "Inner #{term} 1")
      end

      let_it_be(:internal_project_2) do
        create(:project, :internal, namespace: nested_group, name: "Inner #{term} 2")
      end

      let_it_be(:internal_project_3) do
        create(:project, :internal, namespace: nested_group.parent, name: "Outer #{term}")
      end

      before_all do
        # Ensure these are present when the index is refreshed
        Elastic::ProcessInitialBookkeepingService.track!(
          outside_project, private_project, other_project, internal_project_1, internal_project_2, internal_project_3
        )

        ensure_elasticsearch_index!
      end

      subject { results.objects('projects') }

      context 'in parent group' do
        let(:search_group) { nested_group.parent }

        it { is_expected.to match_array([internal_project_1, internal_project_2, internal_project_3]) }
      end

      context 'in subgroup' do
        let(:search_group) { nested_group }

        it { is_expected.to match_array([internal_project_1, internal_project_2]) }
      end
    end

    context 'for issues scope' do
      let(:term) { 'Goodbye' }
      let(:search_group) { group }
      let_it_be(:issue) { create(:issue, project: project, title: 'Hello world, here I am!') }
      let_it_be(:note) { create(:note_on_issue, note: 'Goodbye moon', noteable: issue, project: issue.project) }

      before do
        Elastic::ProcessInitialBookkeepingService.track!(issue, note)
        ensure_elasticsearch_index!
      end

      subject(:issues) { results.objects('issues') }

      it 'return the issue when searching with note text' do
        expect(issues).to contain_exactly(issue)
        expect(results.issues_count).to eq 1
      end
    end
  end

  describe '#elasticsearchable_scope' do
    let(:service) { described_class.new(user, group, scope: scope) }
    let(:scope) { 'blobs' }

    it 'is set to group' do
      expect(service.elasticsearchable_scope).to eq(group)
    end

    context 'when the scope is users' do
      let(:scope) { 'users' }

      it 'is nil' do
        expect(service.elasticsearchable_scope).to be_nil
      end
    end
  end

  describe '#zoekt_node_id' do
    let(:scope) { 'blobs' }
    let_it_be(:node) { create(:zoekt_node) }
    let_it_be(:zoekt_enabled_namespace) { create(:zoekt_enabled_namespace, namespace: group.root_ancestor) }
    let_it_be(:root_id) { group.root_ancestor.id }

    before do
      create(:zoekt_index, zoekt_enabled_namespace: zoekt_enabled_namespace, node: node, namespace_id: root_id)
    end

    subject { described_class.new(user, group, scope: scope).zoekt_node_id }

    it { is_expected.to be_nil }
  end

  context 'when searching with Zoekt', :zoekt_settings_enabled do
    let(:service) do
      described_class.new(user, group, search: 'foobar', scope: scope, page: page, source: source)
    end

    let(:source) { nil }
    let(:use_zoekt) { true }
    let(:scope) { 'blobs' }
    let(:page) { nil }
    let_it_be(:zoekt_nodes_list) { create_list(:zoekt_node, 2) }
    let(:zoekt_nodes) { Search::Zoekt::Node.id_in(zoekt_nodes_list) }

    before do
      allow(group).to receive_messages(use_zoekt?: use_zoekt, search_code_with_zoekt?: use_zoekt)
      zoekt_ensure_namespace_indexed!(group)

      allow(service).to receive(:zoekt_nodes).and_return zoekt_nodes
    end

    it 'returns a Search::Zoekt::SearchResults' do
      expect(service.use_zoekt?).to be(true)
      expect(service.zoekt_searchable_scope).to eq(group)
      expect(service.execute).to be_kind_of(::Search::Zoekt::SearchResults)
    end

    context 'when advanced search is disabled' do
      before do
        stub_ee_application_setting(elasticsearch_search: false, elasticsearch_indexing: false)
      end

      context 'and all replicas are in ready state' do
        before do
          group.zoekt_enabled_namespace.replicas.update_all(state: :ready)
        end

        it 'returns a Search::Zoekt::SearchResults' do
          expect(service.use_zoekt?).to be(true)
          expect(service.zoekt_searchable_scope).to eq(group)
          expect(service.execute).to be_kind_of(::Search::Zoekt::SearchResults)
        end
      end
    end

    context 'when group does not have Zoekt enabled' do
      let(:use_zoekt) { false }

      it 'does not search with Zoekt' do
        expect(service.use_zoekt?).to be(false)
        expect(service.execute).not_to be_kind_of(::Search::Zoekt::SearchResults)
      end
    end

    context 'when scope is not blobs' do
      let(:scope) { 'issues' }

      it 'does not search with Zoekt' do
        expect(service.search_type).not_to eq('zoekt')
        expect(service.execute).not_to be_kind_of(::Search::Zoekt::SearchResults)
      end
    end

    context 'when basic search is requested' do
      let(:service) do
        described_class.new(user, group, search: 'foobar', scope: scope,
          page: page, source: source, search_type: 'basic')
      end

      it 'does not search with Zoekt' do
        expect(service.search_type).to eq('basic')
        expect(service.execute).not_to be_kind_of(::Search::Zoekt::SearchResults)
      end
    end

    context 'when application setting zoekt_search_enabled is disabled' do
      before do
        stub_ee_application_setting(zoekt_search_enabled: false)
      end

      it 'does not search with Zoekt' do
        expect(service.use_zoekt?).to be(false)
        expect(service.execute).not_to be_kind_of(::Search::Zoekt::SearchResults)
      end
    end

    context 'when requesting the first page' do
      let(:page) { 1 }

      it 'searches with Zoekt' do
        expect(service.use_zoekt?).to be(true)
        expect(service.execute).to be_kind_of(::Search::Zoekt::SearchResults)
      end
    end

    context 'when requesting a page other than the first' do
      let(:page) { 2 }

      it 'does not search with Zoekt' do
        expect(service.use_zoekt?).to be(true)
        expect(service.execute).to be_kind_of(::Search::Zoekt::SearchResults)
      end
    end

    context 'when zoekt_code_search licensed feature is disabled' do
      before do
        stub_licensed_features(zoekt_code_search: false)
      end

      it 'does not search with Zoekt' do
        expect(service.use_zoekt?).to be(false)
        expect(service.execute).not_to be_kind_of(::Search::Zoekt::SearchResults)
      end
    end

    context 'when search comes from API' do
      let(:source) { 'api' }

      it 'searches with Zoekt' do
        expect(service.use_zoekt?).to be(true)
        expect(service.execute).to be_kind_of(::Search::Zoekt::SearchResults)
      end
    end
  end

  context 'when sorting', :elastic do
    context 'for issues' do
      let_it_be(:old_result) { create(:work_item, project: project, title: 'sorted old', created_at: 1.month.ago) }
      let_it_be(:new_result) { create(:work_item, project: project, title: 'sorted recent', created_at: 1.day.ago) }
      let_it_be(:very_old_result) do
        create(:work_item, project: project, title: 'sorted very old', created_at: 1.year.ago)
      end

      let_it_be(:old_updated) { create(:work_item, project: project, title: 'updated old', updated_at: 1.month.ago) }
      let_it_be(:new_updated) { create(:work_item, project: project, title: 'updated recent', updated_at: 1.day.ago) }
      let_it_be(:very_old_updated) do
        create(:work_item, project: project, title: 'updated very old', updated_at: 1.year.ago)
      end

      let(:results_created) { described_class.new(nil, group, search: 'sorted', sort: sort).execute }
      let(:results_updated) { described_class.new(nil, group, search: 'updated', sort: sort).execute }

      let(:scope) { 'issues' }

      before do
        Elastic::ProcessInitialBookkeepingService.backfill_projects!(project)
        ensure_elasticsearch_index!
      end

      include_examples 'search results sorted'
    end

    context 'for merge requests' do
      let(:scope) { 'merge_requests' }
      let_it_be(:new_result) do
        create(:merge_request, :opened, source_project: project,
          source_branch: 'new-1', title: 'sorted recent', created_at: 1.day.ago)
      end

      let_it_be(:old_result) do
        create(:merge_request, :opened, source_project: project,
          source_branch: 'old-1', title: 'sorted old', created_at: 1.month.ago)
      end

      let_it_be(:very_old_result) do
        create(:merge_request, :opened, source_project: project,
          source_branch: 'very-old-1', title: 'sorted very old', created_at: 1.year.ago)
      end

      let_it_be(:new_updated) do
        create(:merge_request, :opened, source_project: project,
          source_branch: 'updated-new-1', title: 'updated recent', updated_at: 1.day.ago)
      end

      let_it_be(:old_updated) do
        create(:merge_request, :opened, source_project: project,
          source_branch: 'updated-old-1', title: 'updated old', updated_at: 1.month.ago)
      end

      let_it_be(:very_old_updated) do
        create(:merge_request, :opened, source_project: project,
          source_branch: 'updated-very-old-1', title: 'updated very old', updated_at: 1.year.ago)
      end

      before do
        Elastic::ProcessInitialBookkeepingService.backfill_projects!(project)
        ensure_elasticsearch_index!
      end

      include_examples 'search results sorted' do
        let(:results_created) { described_class.new(nil, group, search: 'sorted', sort: sort).execute }
        let(:results_updated) { described_class.new(nil, group, search: 'updated', sort: sort).execute }
      end
    end

    context 'for group level work_items' do
      let(:scope) { 'epics' }
      let_it_be(:member) { create(:group_member, :owner, group: group, user: user) }

      let_it_be(:old_result) do
        create(:work_item, :group_level, :epic_with_legacy_epic, namespace: group, title: 'sorted old',
          created_at: 1.month.ago)
      end

      let_it_be(:new_result) do
        create(:work_item, :group_level, :epic_with_legacy_epic, namespace: group, title: 'sorted recent',
          created_at: 1.day.ago)
      end

      let_it_be(:very_old_result) do
        create(:work_item, :group_level, :epic_with_legacy_epic, namespace: group, title: 'sorted very old',
          created_at: 1.year.ago)
      end

      let_it_be(:old_updated) do
        create(:work_item, :group_level, :epic_with_legacy_epic, namespace: group, title: 'updated old',
          updated_at: 1.month.ago)
      end

      let_it_be(:new_updated) do
        create(:work_item, :group_level, :epic_with_legacy_epic, namespace: group, title: 'updated recent',
          updated_at: 1.day.ago)
      end

      let_it_be(:very_old_updated) do
        create(:work_item, :group_level, :epic_with_legacy_epic, namespace: group, title: 'updated very old',
          updated_at: 1.year.ago)
      end

      let(:results_created) { described_class.new(user, group, search: 'sorted', sort: sort).execute }
      let(:results_updated) { described_class.new(user, group, search: 'updated', sort: sort).execute }

      before do
        stub_licensed_features(epics: true)
        Elastic::ProcessInitialBookkeepingService.track!(old_result, new_result, very_old_result,
          old_updated, new_updated, very_old_updated
        )
        ensure_elasticsearch_index!
      end

      include_examples 'search results sorted'
    end
  end

  describe '#allowed_scopes' do
    let_it_be(:group) { create(:group) }
    let(:service) { described_class.new(user, group, {}) }

    subject(:allowed_scopes) { service.allowed_scopes }

    context 'for blobs scope' do
      context 'when elasticearch_search is disabled and zoekt is disabled' do
        before do
          stub_ee_application_setting(elasticsearch_search: false)
          allow(::Search::Zoekt).to receive(:search_enabled?).and_return(false)
        end

        it { is_expected.not_to include('blobs') }
      end

      context 'when elasticsearch_search is enabled and zoekt is disabled' do
        before do
          stub_ee_application_setting(elasticsearch_search: true)
          allow(::Search::Zoekt).to receive(:search_enabled?).and_return(false)
        end

        it { is_expected.to include('blobs') }
      end

      context 'when elasticsearch_search is disabled and zoekt is enabled' do
        before do
          stub_ee_application_setting(elasticsearch_search: false)
          allow(::Search::Zoekt).to receive(:search_enabled?).and_return(true)
          allow(::Search::Zoekt).to receive(:search?).with(group).and_return(true)
        end

        it { is_expected.to include('blobs') }

        context 'and the group is not enabled for zoekt' do
          before do
            allow(::Search::Zoekt).to receive(:search?).with(group).and_return(false)
          end

          it { is_expected.not_to include('blobs') }
        end
      end
    end

    context 'for epics scope' do
      before do
        stub_licensed_features(epics: epics_available)
      end

      context 'when epics available' do
        let(:epics_available) { true }

        it 'includes epics to allowed_scopes using registry logic' do
          expect(allowed_scopes).to include('epics')
        end

        context 'with advanced search' do
          before do
            stub_ee_application_setting(elasticsearch_search: true)
          end

          it 'includes epics to allowed_scopes' do
            expect(allowed_scopes).to include('epics')
          end
        end

        context 'with basic search' do
          before do
            stub_ee_application_setting(elasticsearch_search: false)
          end

          it 'includes epics to allowed_scopes' do
            expect(allowed_scopes).to include('epics')
          end
        end
      end

      context 'when epics is not available' do
        let(:epics_available) { false }

        it 'filters out epics from allowed_scopes' do
          expect(allowed_scopes).not_to include('epics')
        end

        context 'with advanced search' do
          before do
            stub_ee_application_setting(elasticsearch_search: true)
          end

          it 'filters out epics from allowed_scopes' do
            expect(allowed_scopes).not_to include('epics')
          end
        end

        context 'with basic search' do
          before do
            stub_ee_application_setting(elasticsearch_search: false)
          end

          it 'filters out epics from allowed_scopes' do
            expect(allowed_scopes).not_to include('epics')
          end
        end
      end
    end
  end
end
