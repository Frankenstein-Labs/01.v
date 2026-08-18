# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Elastic::ProjectsSearch, feature_category: :global_search do
  include EE::GeoHelpers

  subject(:projects_search) do
    Class.new do
      include Elastic::ProjectsSearch

      def id
        1
      end

      def es_id
        1
      end

      def pending_delete?
        false
      end

      def project_feature
        ProjectFeature.new
      end

      def root_namespace
        Namespace.new
      end

      def empty_repo?
        false
      end
    end.new
  end

  describe '#maintain_elasticsearch_create' do
    it 'calls track!' do
      expect(::Search::Elastic::CommitIndexerWorker).not_to receive(:perform_async)
      expect(::Elastic::ProcessInitialBookkeepingService).to receive(:track!).and_return(true)

      projects_search.maintain_elasticsearch_create
    end

    context 'when project is empty_repo' do
      subject(:projects_search) do
        Class.new do
          include Elastic::ProjectsSearch

          def id
            1
          end

          def es_id
            1
          end

          def pending_delete?
            false
          end

          def project_feature
            ProjectFeature.new
          end

          def root_namespace
            Namespace.new
          end

          def empty_repo?
            true
          end
        end.new
      end

      it 'calls track! and CommitIndexerWorker' do
        expect(::Search::Elastic::CommitIndexerWorker).to receive(:perform_async).with(1)
        expect(::Elastic::ProcessInitialBookkeepingService).to receive(:track!).and_return(true)

        projects_search.maintain_elasticsearch_create
      end
    end
  end

  describe '#maintain_elasticsearch_update' do
    using RSpec::Parameterized::TableSyntax

    where(:attribute_updated, :geo, :commit_indexing_expected, :wiki_indexing_expected) do
      :archived         | :disabled  | true  | true
      :name             | :disabled  | false | false
      :visibility_level | :disabled  | true  | true

      :archived         | :primary   | true  | true
      :name             | :primary   | false | false
      :visibility_level | :primary   | true  | true

      :archived         | :secondary | false | true
      :name             | :secondary | false | false
      :visibility_level | :secondary | false | true
    end

    with_them do
      before do
        public_send(:"stub_#{geo}_node") unless geo == :disabled
      end

      it 'initiates repository reindexing when attributes change for when indexing is expected' do
        expect(::Elastic::ProcessBookkeepingService).to receive(:track!).once.and_return(true)

        if commit_indexing_expected
          expect(::Search::Elastic::CommitIndexerWorker).to receive(:perform_async).and_return(true)
        else
          expect(::Search::Elastic::CommitIndexerWorker).not_to receive(:perform_async)
        end

        if wiki_indexing_expected
          expect(::ElasticWikiIndexerWorker).to receive(:perform_async).and_return(true)
        else
          expect(::ElasticWikiIndexerWorker).not_to receive(:perform_async)
        end

        projects_search.maintain_elasticsearch_update(updated_attributes: [attribute_updated])
      end
    end
  end

  describe '#maintain_elasticsearch_destroy' do
    it 'calls delete worker' do
      expect(ElasticDeleteProjectWorker).to receive(:perform_async)

      projects_search.maintain_elasticsearch_destroy
    end
  end
end
