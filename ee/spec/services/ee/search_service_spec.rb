# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SearchService, feature_category: :global_search do
  describe '#search_objects' do
    let(:scope) { nil }
    let(:page) { 1 }
    let(:per_page) { described_class::DEFAULT_PER_PAGE }

    subject(:search_service) { described_class.new(user, search: search, scope: scope, page: page, per_page: per_page) }

    it_behaves_like 'a redacted search results'
  end

  describe '#search_counts' do
    let_it_be(:user) { create(:user) }
    let(:search) { 'anything' }
    let(:scope) { nil }
    let(:page) { 1 }
    let(:per_page) { described_class::DEFAULT_PER_PAGE }

    subject(:search_service) { described_class.new(user, search: search, scope: scope, page: page, per_page: per_page) }

    it 'calls search_results.counts' do
      expect_next_instance_of(Gitlab::SearchResults) do |search_results|
        expect(search_results).to receive(:counts)
      end

      search_service.search_counts
    end
  end

  describe '#use_elasticsearch?' do
    let_it_be(:user) { create(:user) }

    context 'when project is present' do
      let_it_be(:project) { create(:project, :public) }

      it 'Search::ProjectService receives use_elasticsearch?' do
        expect_next_instance_of(::Search::ProjectService) do |project_service|
          expect(project_service).to receive(:use_elasticsearch?).and_return 'result'
        end
        expect(described_class.new(user, project_id: project.id.to_s).use_elasticsearch?).to eq 'result'
      end
    end

    context 'when project is not present' do
      it 'Search::GlobalService receives use_elasticsearch?' do
        expect_next_instance_of(::Search::GlobalService) do |global_service|
          expect(global_service).to receive(:use_elasticsearch?).and_return 'result'
        end
        expect(described_class.new(user).use_elasticsearch?).to eq 'result'
      end
    end
  end

  describe '.global_search_enabled_for_scope?' do
    using RSpec::Parameterized::TableSyntax
    let_it_be(:user) { create(:user) }
    let(:search_service) { described_class.new(user, { scope: scope, search: search }) }
    let(:search) { 'foobar' }

    where(:scope, :admin_setting, :setting_enabled, :expected) do
      'blobs'          | :global_search_code_enabled           | false | false
      'blobs'          | :global_search_code_enabled           | true  | true
      'commits'        | :global_search_commits_enabled        | false | false
      'commits'        | :global_search_commits_enabled        | true  | true
      'epics'          | :global_search_work_items_enabled     | false | false
      'epics'          | :global_search_work_items_enabled     | true  | true
      'wiki_blobs'     | :global_search_wiki_enabled           | false | false
      'wiki_blobs'     | :global_search_wiki_enabled           | true  | true
    end

    with_them do
      it 'returns false when feature_flag is not enabled and returns true when feature_flag is enabled' do
        stub_application_setting(admin_setting => setting_enabled)
        expect(search_service.global_search_enabled_for_scope?).to eq expected
      end
    end
  end

  describe '#search_type' do
    let_it_be(:user) { create(:user) }
    let_it_be(:project) { create(:project, :public) }
    let_it_be(:group) { create(:group, :public) }
    let(:scope) { 'notes' }
    let(:expected_search_type) { 'advanced' }

    subject(:search_type) { service.search_type }

    context 'for project search' do
      let(:service) { described_class.new(user, { scope: scope, project_id: project.id }) }

      it 'delegates to ProjectService.search_type' do
        expect_next_instance_of(::Search::ProjectService) do |project_service|
          expect(project_service).to receive(:search_type).and_return(expected_search_type)
        end

        expect(search_type).to eq(expected_search_type)
      end
    end

    context 'for group search' do
      let(:service) { described_class.new(user, { scope: scope, group_id: group.id }) }

      it 'delegates to GroupService.search_type' do
        expect_next_instance_of(::Search::GroupService) do |group_service|
          expect(group_service).to receive(:search_type).and_return(expected_search_type)
        end

        expect(search_type).to eq(expected_search_type)
      end
    end

    context 'for global search' do
      let(:service) { described_class.new(user, { scope: scope }) }

      it 'delegates to GlobalService.search_type' do
        expect_next_instance_of(::Search::GlobalService) do |global_service|
          expect(global_service).to receive(:search_type).and_return(expected_search_type)
        end

        expect(search_type).to eq(expected_search_type)
      end
    end
  end

  describe '#search_type_errors' do
    let_it_be(:user) { create(:user) }
    let(:search_service) { described_class.new(user, { scope: scope, search_type: search_type }) }
    let(:scope) { 'blobs' }

    context 'when search_type is basic' do
      let(:search_type) { 'basic' }

      it 'is nil' do
        expect(search_service.search_type_errors).to be_nil
      end
    end

    context 'when search_type is nil' do
      let(:search_type) { nil }

      it 'is nil' do
        expect(search_service.search_type_errors).to be_nil
      end
    end

    context 'when search_type is advanced' do
      let(:search_type) { 'advanced' }

      it 'is nil if use_elasticsearch?' do
        allow(search_service).to receive(:use_elasticsearch?).and_return(true)

        expect(search_service.search_type_errors).to be_nil
      end

      it 'returns an error if not use_elasticsearch?' do
        allow(search_service).to receive(:use_elasticsearch?).and_return(false)

        expect(search_service.search_type_errors).to eq('Advanced search is not available')
      end

      it 'returns an error if elasticsearch_code_scope is false' do
        stub_ee_application_setting(elasticsearch_code_scope: false)

        expect(search_service.search_type_errors).to eq("Advanced search is disabled for #{scope}")
      end
    end

    context 'when search_type is zoekt' do
      let(:search_type) { 'zoekt' }

      it 'is nil if use_zoekt?' do
        allow(search_service).to receive(:use_zoekt?).and_return(true)

        expect(search_service.search_type_errors).to be_nil
      end

      it 'returns an error if not use_zoekt?' do
        allow(search_service).to receive(:use_zoekt?).and_return(false)

        expect(search_service.search_type_errors).to eq('Exact code search is not available')
      end

      context 'when scope is not blobs' do
        let(:scope) { 'issues' }

        it 'returns an error' do
          allow(search_service).to receive(:use_zoekt?).and_return(true)

          expect(search_service.search_type_errors).to eq('Exact code search can only be used for blobs')
        end
      end

      context 'when checking project limit' do
        let_it_be(:group) { create(:group) }
        let_it_be(:projects) { create_list(:project, 5, namespace: group) }
        let(:search_service) do
          described_class.new(user, { scope: scope, search_type: search_type, group_id: group.id })
        end

        before do
          allow(search_service).to receive(:use_zoekt?).and_return(true)
        end

        context 'when project count exceeds 1000 without traversal_id_search' do
          before do
            allow_next_found_instance_of(Group) do |group_instance|
              allow(group_instance).to receive_message_chain(:all_projects, :limit, :count).and_return(1001)
            end
            allow(::Search::Zoekt).to receive(:feature_available?)
              .with(:traversal_id_search, user, group_id: group.id, project_id: nil)
              .and_return(false)
          end

          it 'returns an error message' do
            expect(search_service.search_type_errors).to include('Your search includes too many projects')
            expect(search_service.search_type_errors).to include('Only the first 1000 projects are shown')
          end
        end

        context 'when project count exceeds 1000 with traversal_id_search enabled' do
          before do
            allow_next_found_instance_of(Group) do |group_instance|
              allow(group_instance).to receive_message_chain(:all_projects, :limit, :count).and_return(1001)
            end
            allow(::Search::Zoekt).to receive(:feature_available?)
              .with(:traversal_id_search, user, group_id: group.id, project_id: nil)
              .and_return(true)
          end

          it 'returns nil' do
            expect(search_service.search_type_errors).to be_nil
          end
        end

        context 'when project count is below 1000 without traversal_id_search' do
          before do
            allow_next_found_instance_of(Group) do |group_instance|
              allow(group_instance).to receive_message_chain(:all_projects, :limit, :count).and_return(500)
            end
            allow(::Search::Zoekt).to receive(:feature_available?)
              .with(:traversal_id_search, user, group_id: group.id, project_id: nil)
              .and_return(false)
          end

          it 'returns nil' do
            expect(search_service.search_type_errors).to be_nil
          end
        end

        context 'when project-level search with over 1000 projects' do
          let(:search_service) do
            described_class.new(user, { scope: scope, search_type: search_type, project_id: projects.first.id })
          end

          before do
            allow(::Search::Zoekt).to receive(:feature_available?)
              .with(:traversal_id_search, user, group_id: nil, project_id: projects.first.id)
              .and_return(false)
          end

          it 'returns nil' do
            expect(search_service.search_type_errors).to be_nil
          end
        end

        context 'when project-level search with group_id and project_id both present' do
          let(:search_service) do
            described_class.new(user, {
              scope: scope,
              search_type: search_type,
              group_id: group.id,
              project_id: projects.first.id
            })
          end

          before do
            allow_next_found_instance_of(Group) do |group_instance|
              allow(group_instance).to receive_message_chain(:all_projects, :limit, :count).and_return(1001)
            end
            allow(::Search::Zoekt).to receive(:feature_available?)
              .with(:traversal_id_search, user, group_id: group.id, project_id: projects.first.id)
              .and_return(false)
          end

          it 'returns nil because project_id indicates a project-level search' do
            expect(search_service.search_type_errors).to be_nil
          end
        end
      end
    end

    context 'when search_type is random' do
      let(:search_type) { 'foobar' }

      it 'returns an error' do
        message = "Search type should be one of these: #{described_class.supported_search_types.join(', ')}"
        expect(search_service.search_type_errors).to eq(message)
      end

      it 'still allows scope determination to work' do
        stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)

        expect(search_service.scope).to eq('blobs')
      end
    end
  end

  describe 'invalid search_type handling' do
    let_it_be(:user) { create(:user) }
    let_it_be(:project) { create(:project) }

    it 'returns proper error for invalid search_type but allows scope to be determined' do
      search_service = described_class.new(user, {
        project_id: project.id,
        scope: 'work_items',
        search_type: 'invalid_xyz',
        search: 'test'
      })

      # Scope should be determinable
      expect(search_service.scope).to eq('work_items')

      # But search_type_errors should return validation error
      expect(search_service.search_type_errors).to include('Search type should be one of these')
    end
  end
end
