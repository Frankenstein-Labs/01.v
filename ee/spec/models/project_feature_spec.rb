# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProjectFeature, feature_category: :groups_and_projects do
  include EE::GeoHelpers

  let_it_be_with_reload(:project) { create(:project, :public) }
  let_it_be_with_reload(:user) { create(:user) }

  describe 'default values' do
    subject(:project_feature) { Project.new.project_feature }

    specify { expect(project_feature.requirements_access_level).to eq(Featurable::ENABLED) }
  end

  describe '#feature_available?' do
    let(:features) { %w[issues wiki builds merge_requests snippets repository pages] }

    context 'when features are enabled only for team members' do
      it "returns true if user is an auditor" do
        user.update_attribute(:auditor, true)

        features.each do |feature|
          project.project_feature.update_attribute(:"#{feature}_access_level", ProjectFeature::PRIVATE)
          expect(project.feature_available?(:issues, user)).to be(true)
        end
      end
    end
  end

  describe 'project visibility changes', feature_category: :global_search do
    using RSpec::Parameterized::TableSyntax

    context 'for repository' do
      where(:maintaining_elasticsearch, :maintaining_indexed_associations, :geo, :worker_expected) do
        true  | true  | :disabled   | true
        true  | true  | :primary    | true
        true  | true  | :secondary  | false

        false | true  | :disabled   | false
        true  | false | :disabled   | false
        false | false | :disabled   | false
      end

      with_them do
        before do
          public_send(:"stub_#{geo}_node") unless geo == :disabled

          allow(project).to receive_messages(maintaining_elasticsearch?: maintaining_elasticsearch,
            maintaining_indexed_associations?: maintaining_indexed_associations)
        end

        context 'when updating repository_access_level' do
          it 'initiates commits reindexing when expected' do
            if worker_expected
              expect(Search::Elastic::CommitIndexerWorker).to receive(:perform_async)
                .with(project.id, { 'force' => true })
            else
              expect(Search::Elastic::CommitIndexerWorker).not_to receive(:perform_async)
            end

            project.project_feature.update_attribute(:repository_access_level, ProjectFeature::DISABLED)
          end
        end
      end
    end

    context 'for wiki' do
      where(:maintaining_elasticsearch, :maintaining_indexed_associations, :worker_expected) do
        true  | true  | true
        false | true  | false
        true  | false | false
        false | false | false
      end

      with_them do
        before do
          allow(project).to receive_messages(maintaining_elasticsearch?: maintaining_elasticsearch,
            maintaining_indexed_associations?: maintaining_indexed_associations)
        end

        context 'when updating wiki_access_level' do
          it 'enqueues a worker to index commit data' do
            if worker_expected
              expect(ElasticWikiIndexerWorker).to receive(:perform_async)
                .with(project.id, 'Project', { 'force' => true })
            else
              expect(ElasticWikiIndexerWorker).not_to receive(:perform_async)
            end

            project.project_feature.update_attribute(:wiki_access_level, ProjectFeature::DISABLED)
          end
        end
      end
    end

    context 'for associations in the database' do
      where(:project_feature, :maintaining_elasticsearch, :maintaining_indexed_associations, :worker_expected,
        :associations) do
        'issues'                  | true  | true  | true  | %w[issues notes milestones]
        'issues'                  | false | true  | false | nil
        'issues'                  | true  | false | false | nil
        'issues'                  | false | false | false | nil
        'builds'                  | true  | true  | false | nil
        'builds'                  | false | true  | false | nil
        'builds'                  | true  | false | false | nil
        'builds'                  | false | false | false | nil
        'merge_requests'          | true  | true  | true  | %w[merge_requests notes milestones]
        'merge_requests'          | false | true  | false | nil
        'merge_requests'          | true  | false | false | nil
        'merge_requests'          | false | false | false | nil
        'repository'              | true  | true  | true  | %w[notes]
        'repository'              | false | true  | false | nil
        'repository'              | true  | false | false | nil
        'repository'              | false | false | false | nil
        'snippets'                | true  | true  | true  | %w[notes]
        'snippets'                | false | true  | false | nil
        'snippets'                | true  | false | false | nil
        'snippets'                | false | false | false | nil
        'operations'              | true  | true  | false | nil
        'operations'              | false | true  | false | nil
        'operations'              | true  | false | false | nil
        'operations'              | false | false | false | nil
        'security_and_compliance' | true  | true  | false | nil
        'security_and_compliance' | false | true  | false | nil
        'security_and_compliance' | true  | false | false | nil
        'security_and_compliance' | false | false | false | nil
        'pages'                   | true  | true  | false | nil
        'pages'                   | false | true  | false | nil
        'pages'                   | true  | false | false | nil
        'pages'                   | false | false | false | nil
      end

      with_them do
        before do
          allow(project).to receive_messages(maintaining_elasticsearch?: maintaining_elasticsearch,
            maintaining_indexed_associations?: maintaining_indexed_associations)
        end

        it 're-indexes project and project associations on update' do
          if maintaining_elasticsearch
            expect(project).to receive(:maintain_elasticsearch_update)
          else
            expect(project).not_to receive(:maintain_elasticsearch_update)
          end

          if worker_expected
            expect(ElasticAssociationIndexerWorker).to receive(:perform_async).with('Project', project.id, associations)
          else
            expect(ElasticAssociationIndexerWorker).not_to receive(:perform_async)
          end

          project.project_feature.update_attribute(:"#{project_feature}_access_level", ProjectFeature::DISABLED)
        end
      end
    end
  end

  it_behaves_like 'access level validation', ProjectFeature::EE_FEATURES do
    let(:container_features) { project.project_feature }
  end
end
