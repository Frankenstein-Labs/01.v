# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ArtifactRegistry::RendersErrors, feature_category: :artifact_registry do
  let(:test_class) do
    Class.new do
      include ::ArtifactRegistry::RendersErrors

      def run(operation: :query, errors: nil, &block)
        render_artifact_registry_response(operation: operation, errors: errors, &block)
      end
    end
  end

  subject(:renderer) { test_class.new }

  describe '#render_artifact_registry_response' do
    context 'with a successful outcome (passthrough)' do
      using RSpec::Parameterized::TableSyntax

      where(:case_name, :value) do
        'a plain value'                | 'ok'
        'nil (read 404 -> null field)' | nil
        'true (idempotent delete 404)' | true
      end

      with_them do
        it 'returns the yielded value unchanged' do
          expect(renderer.run { value }).to eq(value)
        end
      end
    end

    context 'with a 401/403 AuthorizationError' do
      let(:error) do
        ArtifactRegistry::Client::AuthorizationError.new('forbidden', status: 403, request_id: 'req-1')
      end

      it 'renders null on a query (existence-hiding)' do
        expect(renderer.run(operation: :query) { raise error }).to be_nil
      end

      it 'raises ResourceNotAvailable carrying request_id on a mutation', :aggregate_failures do
        expect { renderer.run(operation: :mutation, errors: []) { raise error } }
          .to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable) do |raised|
            expect(raised.extensions).to include(request_id: 'req-1')
          end
      end
    end

    context 'with a no-credential AuthorizationError (fail-closed, no HTTP status)' do
      let(:error) { ArtifactRegistry::Client::AuthorizationError.new('no credential') }

      it 'reports to error tracking and raises ServiceUnavailable', :aggregate_failures do
        expect(Gitlab::ErrorTracking).to receive(:log_exception).with(error)

        expect { renderer.run { raise error } }
          .to raise_error(Gitlab::Graphql::Errors::ArtifactRegistry::ServiceUnavailable)
      end
    end

    context 'with an UnavailableError (transport / 5xx / 429)' do
      let(:error) do
        ArtifactRegistry::Client::UnavailableError.new('down', status: 503, request_id: 'req-2')
      end

      it 'raises ServiceUnavailable with request_id and does not re-report (the client already did)',
        :aggregate_failures do
        expect(Gitlab::ErrorTracking).not_to receive(:log_exception)

        expect { renderer.run { raise error } }
          .to raise_error(Gitlab::Graphql::Errors::ArtifactRegistry::ServiceUnavailable) do |raised|
            expect(raised.extensions).to include(request_id: 'req-2')
          end
      end
    end

    context 'with an ApiError (400/409/422 etc.)' do
      let(:error) do
        ArtifactRegistry::Client::ApiError.new('bad request', status: 400, code: 'INVALID', request_id: 'req-3')
      end

      it 'raises a top-level error carrying code and message on a query', :aggregate_failures do
        expect { renderer.run(operation: :query) { raise error } }
          .to raise_error(Gitlab::Graphql::Errors::BaseError, 'bad request') do |raised|
            expect(raised.extensions).to include(code: 'INVALID', request_id: 'req-3')
          end
      end

      it 'appends the message to the payload errors on a mutation and resolves nil', :aggregate_failures do
        errors = []

        result = renderer.run(operation: :mutation, errors: errors) { raise error }

        expect(result).to be_nil
        expect(errors).to contain_exactly('bad request')
      end

      it 'falls back to a generic message when the error carries none' do
        blank_error = ArtifactRegistry::Client::ApiError.new(nil, status: 422)

        expect { renderer.run(operation: :query) { raise blank_error } }
          .to raise_error(Gitlab::Graphql::Errors::BaseError, 'Artifact Registry returned an error.')
      end
    end

    context 'with an ArgumentError from the client argument guards' do
      it 'renders it as a GraphQL argument error rather than an unhandled 500' do
        expect { renderer.run { raise ArgumentError, 'name is required' } }
          .to raise_error(Gitlab::Graphql::Errors::ArgumentError, 'name is required')
      end
    end

    context 'when a mutation threads no errors array' do
      it 'raises rather than dropping recoverable errors into a throwaway array' do
        expect { renderer.run(operation: :mutation) { 'ok' } }
          .to raise_error(ArgumentError, '`errors:` is required when operation is :mutation')
      end
    end
  end
end
