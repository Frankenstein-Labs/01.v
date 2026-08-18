# frozen_string_literal: true

module Ai
  module ActiveContext
    module References
      class Code < ::ActiveContext::Reference
        include Ai::ActiveContext::References::Preprocessors::CodeRootNamespaceResolver

        add_preprocessor :get_content do |refs, queue_name: nil, skip_missing_content: false, **|
          identifiers = refs.map(&:identifier)
          query = ::ActiveContext::Query.filter(id: identifiers).limit(identifiers.count)

          fetch_content(
            refs: refs,
            query: query,
            collection: Collections::Code,
            queue_name: queue_name,
            skip_missing_content: skip_missing_content
          )
        end

        add_preprocessor(
          :resolve_root_namespace,
          should_run: -> { request_embeddings_by_root_namespace? }
        ) do |refs, queue_name: nil, **|
          resolve_code_root_namespace(refs: refs, queue_name: queue_name)
        end

        add_preprocessor :embeddings do |refs, queue_name: nil, next_model_only: false, **|
          apply_embeddings_method = if request_embeddings_by_root_namespace?
                                      :apply_embeddings_by_root_namespace
                                    else
                                      :apply_embeddings
                                    end

          send( # rubocop: disable GitlabSecurity/PublicSend -- the method names used are from 2 definite options
            apply_embeddings_method,
            refs: refs,
            queue_name: queue_name,
            remove_content: false,
            next_model_only: next_model_only,
            infinite_retry_error_types: [::Gitlab::Llm::Concerns::ExponentialBackoff::RateLimitError]
          )
        end

        def self.serialize_data(data)
          { identifier: data[:id] }
        end

        def self.request_embeddings_by_root_namespace?
          Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)
        end

        attr_accessor :identifier

        def init
          @identifier = serialized_args.first
          @project_id = routing.to_i
        end

        def serialized_attributes
          [identifier]
        end

        def unique_identifier(_)
          identifier
        end

        def operation
          :update
        end

        def as_indexed_json
          {}
        end
      end
    end
  end
end
