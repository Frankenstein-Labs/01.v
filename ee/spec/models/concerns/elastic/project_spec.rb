# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Project, feature_category: :global_search do
  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
  end

  let(:schema_version) { ::Elastic::Latest::ProjectInstanceProxy::SCHEMA_VERSION }
  let_it_be(:admin) { create(:admin) }

  context 'when limited indexing is on' do
    let_it_be(:project) { create(:project, :empty_repo, name: 'main_project') }

    before do
      stub_ee_application_setting(elasticsearch_limit_indexing: true)
    end

    context 'when the project is not enabled specifically' do
      describe '#maintaining_elasticsearch?' do
        subject(:maintaining_elasticsearch) { project.maintaining_elasticsearch? }

        it { is_expected.to be(true) }
      end

      describe '#use_elasticsearch?' do
        subject(:use_elasticsearch) { project.use_elasticsearch? }

        it { is_expected.to be(false) }
      end
    end

    context 'when a project is enabled specifically' do
      before do
        create(:elasticsearch_indexed_project, project: project)
      end

      describe '#maintaining_elasticsearch?' do
        subject(:maintaining_elasticsearch) { project.maintaining_elasticsearch? }

        it { is_expected.to be(true) }
      end

      describe '#use_elasticsearch?' do
        subject(:use_elasticsearch) { project.use_elasticsearch? }

        it { is_expected.to be(true) }
      end

      describe 'indexing', :elastic, :sidekiq_inline, :enable_admin_mode do
        it 'indexes all projects' do
          create(:project, :empty_repo, path: 'test_two', description: 'awesome project')
          ensure_elasticsearch_index!

          options = { current_user: admin, search_level: :global, project_ids: :any }
          expect(described_class.elastic_search('main_project', options: options).total_count).to eq(1)
          expect(described_class.elastic_search('"test_two"', options: options).total_count).to eq(1)
        end
      end
    end

    context 'when a group is enabled', :sidekiq_inline do
      let_it_be(:group) { create(:group) }

      before_all do
        create(:elasticsearch_indexed_namespace, namespace: group)
      end

      describe '#maintaining_elasticsearch?' do
        let_it_be(:project_in_group) { create(:project, name: 'test1', group: group) }

        subject(:maintaining_elasticsearch) { project_in_group.maintaining_elasticsearch? }

        it { is_expected.to be(true) }
      end

      describe 'indexing', :elastic, :enable_admin_mode do
        it 'indexes all projects' do
          create(:project, name: 'group_test1', group: create(:group, parent: group))
          create(:project, name: 'group_test2', description: 'awesome project')
          create(:project, name: 'group_test3', group: group)
          ensure_elasticsearch_index!
          options = { current_user: admin, search_level: :global, project_ids: :any }

          expect(described_class.elastic_search('group_test*', options: options).total_count).to eq(3)
          expect(described_class.elastic_search('"group_test3"', options: options).total_count).to eq(1)
          expect(described_class.elastic_search('"group_test2"', options: options).total_count).to eq(1)
        end
      end

      describe 'default_operator' do
        RSpec.shared_examples 'use correct default_operator' do |operator|
          it 'uses correct operator', :sidekiq_inline do
            create(:project, name: 'project1', group: group, description: 'test foo')
            create(:project, name: 'project2', group: group, description: 'test')
            create(:project, name: 'project3', group: group, description: 'foo')

            ensure_elasticsearch_index!

            count_for_or = described_class.elastic_search('test | foo', options: { project_ids: :any }).total_count
            expect(count_for_or).to be > 0

            count_for_and = described_class.elastic_search('test + foo', options: { project_ids: :any }).total_count
            expect(count_for_and).to be > 0

            expect(count_for_or).not_to be equal(count_for_and)

            expected_count = case operator
                             when :or
                               count_for_or
                             when :and
                               count_for_and
                             else
                               raise ArgumentError, 'Invalid operator'
                             end

            expect(described_class.elastic_search('test foo',
              options: { project_ids: :any }).total_count).to eq(expected_count)
          end
        end
      end
    end
  end

  context 'when user is an admin', :elastic_delete_by_query, :enable_admin_mode do
    it 'finds projects' do
      user = create(:admin)
      project_ids = []

      project = create(:project, name: 'test1')
      project1 = create(:project, path: 'test2', description: 'awesome project')
      project2 = create(:project)
      create(:project, path: 'someone_elses_project')
      project_ids += [project.id, project1.id, project2.id]

      create(:project, :private, name: 'test3')
      options = { current_user: user, search_level: :global, project_ids: project_ids }

      ensure_elasticsearch_index!

      expect(described_class.elastic_search('"test1"', options: options).total_count).to eq(1)
      expect(described_class.elastic_search('"test2"', options: options).total_count).to eq(1)
      expect(described_class.elastic_search('"awesome"', options: options).total_count).to eq(1)
      expect(described_class.elastic_search('test*', options: options).total_count).to eq(3)
      expect(described_class.elastic_search('test*', options: options.merge(project_ids: :any)).total_count).to eq(3)
      expect(described_class.elastic_search('"someone_elses_project"', options: options).total_count).to eq(1)
    end
  end

  it 'finds partial matches in project names', :elastic_delete_by_query do
    project = create(:project, :public, name: 'tesla-model-s')
    project1 = create(:project, :public, name: 'tesla_model_s')
    project_ids = [project.id, project1.id]
    options = { search_level: :global, project_ids: project_ids }

    ensure_elasticsearch_index!

    expect(described_class.elastic_search('tesla', options: options).total_count).to eq(2)
  end
end
