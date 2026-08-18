# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::References::Preprocessors::CodeRootNamespaceResolver, :aggregate_failures, feature_category: :code_suggestions do
  let(:mock_reference_class) do
    Class.new(::ActiveContext::Reference) do
      include Ai::ActiveContext::References::Preprocessors::CodeRootNamespaceResolver

      attr_reader :identifier

      add_preprocessor :resolve_root_namespace do |refs, queue_name: nil, **|
        resolve_code_root_namespace(refs: refs, queue_name: queue_name)
      end

      def init
        @identifier, _ = serialized_args
        @project_id = routing.to_i
      end

      def serialized_attributes
        [identifier]
      end
    end
  end

  let_it_be(:collection) { create(:ai_active_context_collection, :code_collection) }

  let_it_be(:group1) { create(:group) }
  let_it_be(:project1) do
    sub_group = create(:group, parent: group1)
    create(:project, group: sub_group)
  end

  let_it_be(:group2) { create(:group) }
  let_it_be(:project2) { create(:project, group: group2) }

  let_it_be(:user) { create(:user, :with_namespace) }
  let_it_be(:project3) { create(:project, namespace: user.namespace) }

  let(:references) do
    [
      mock_reference_class.new(collection_id: collection.id, routing: project1.id, args: 'hash-id-123'),
      mock_reference_class.new(collection_id: collection.id, routing: project2.id, args: 'hash-id-456'),
      mock_reference_class.new(collection_id: collection.id, routing: project3.id, args: 'hash-id-789')
    ]
  end

  subject(:preprocessed_result) { ActiveContext::Reference.preprocess_references(references) }

  before do
    allow(::ActiveContext::Logger).to receive(:info)
    allow(::ActiveContext::Logger).to receive(:retryable_exception)
  end

  describe '.resolve_code_root_namespace' do
    it "successfully sets each project's root namespace" do
      expect(ActiveContext::Logger).to receive(:info).with(
        message: 'Resolving root_namespace_id for references',
        class_name: anything,
        preprocessor: 'code_root_namespace_resolver',
        refs_count: 3
      )
      expect(ActiveContext::Logger).to receive(:info).with(
        message: 'Resolved root_namespace_id for references',
        class_name: anything,
        preprocessor: 'code_root_namespace_resolver',
        refs_count: 3,
        refs_with_root_namespaces_count: 3,
        unique_root_namespace_ids: [group1.id, group2.id, user.namespace.id]
      )

      expect(preprocessed_result).to eq({
        successful: references, failed: [], retryable: []
      })

      successful_refs = preprocessed_result[:successful]
      expect(successful_refs[0].root_namespace_id).to eq(group1.id)
      expect(successful_refs[1].root_namespace_id).to eq(group2.id)
      expect(successful_refs[2].root_namespace_id).to eq(user.namespace.id)
    end

    context "when a reference's project cannot be found" do
      let(:reference_with_non_existing_project_id) do
        mock_reference_class.new(collection_id: collection.id, routing: non_existing_record_id, args: 'hash-id-123')
      end

      let(:references) { [reference_with_non_existing_project_id] }

      it 'leaves the root namespace id unset' do
        expect(ActiveContext::Logger).to receive(:info).with(
          message: 'Resolving root_namespace_id for references',
          class_name: anything,
          preprocessor: 'code_root_namespace_resolver',
          refs_count: 1
        )
        expect(ActiveContext::Logger).to receive(:info).with(
          message: 'Resolved root_namespace_id for references',
          class_name: anything,
          preprocessor: 'code_root_namespace_resolver',
          refs_count: 1,
          refs_with_root_namespaces_count: 0,
          unique_root_namespace_ids: []
        )

        expect(preprocessed_result).to eq({
          successful: [reference_with_non_existing_project_id], failed: [], retryable: []
        })

        successful_ref = preprocessed_result[:successful].first
        expect(successful_ref.root_namespace_id).to be_nil
      end
    end

    context 'when there are no references' do
      let(:references) { [] }

      it 'leaves the root namespace id unset without query projects' do
        expect(Project).not_to receive(:root_namespace_ids_by_project_ids)

        expect(preprocessed_result).to eq({
          successful: [], failed: [], retryable: []
        })
      end
    end

    context 'when there is an error in resolving namespaces' do
      let(:error) { ActiveRecord::StatementInvalid.new('connection lost') }

      before do
        allow(Project).to receive(:root_namespace_ids_by_project_ids).and_raise(error)
      end

      it 'marks the reference as failed and logs the exception' do
        expect(ActiveContext::Logger).to receive(:retryable_exception).with(
          instance_of(ActiveRecord::StatementInvalid),
          class_name: anything,
          queue_name: nil,
          preprocessor: 'code_root_namespace_resolver',
          infinite_retry: false,
          refs: references.map(&:serialize)
        )

        expect(preprocessed_result).to eq({ successful: [], failed: references, retryable: [] })
      end

      context 'when queue_name is passed' do
        subject(:preprocessed_result) { ActiveContext::Reference.preprocess_references(references, queue_name: 'test_queue') }

        it 'marks the reference as failed and logs the exception with the queue_name' do
          expect(ActiveContext::Logger).to receive(:retryable_exception).with(
            instance_of(ActiveRecord::StatementInvalid),
            class_name: anything,
            queue_name: 'test_queue',
            preprocessor: 'code_root_namespace_resolver',
            infinite_retry: false,
            refs: references.map(&:serialize)
          )

          expect(preprocessed_result).to eq({ successful: [], failed: references, retryable: [] })
        end
      end
    end
  end
end
