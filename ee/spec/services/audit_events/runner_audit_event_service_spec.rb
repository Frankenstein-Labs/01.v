# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AuditEvents::RunnerAuditEventService, feature_category: :runner_core do
  let_it_be(:user) { create(:user) }
  let_it_be(:owner) { create(:user) }

  let(:kwargs) { {} }
  let(:expected_message) { "Created #{runner.runner_type.chomp('_type')} CI runner" }
  let(:service) do
    described_class.new(runner, author, scope, name: expected_attrs[:name], message: expected_message, **kwargs)
  end

  let(:common_attrs) do
    {
      name: SecureRandom.hex(8),
      author: author,
      target: runner
    }
  end

  let(:expected_attrs) do
    common_attrs.merge(
      message: expected_message,
      scope: expected_scope,
      target_details: target_details
    )
  end

  shared_examples 'expected audit event' do
    it 'returns audit event attributes' do
      expect(::Gitlab::Audit::Auditor).to receive(:audit).with(expected_attrs)

      track_event
    end

    context 'with nil message' do
      let(:expected_message) { nil }

      it 'raises an error' do
        expect { track_event }.to raise_error(ArgumentError, 'Missing message')
      end
    end

    context 'with additional kwargs' do
      let(:kwargs) { { action: 'foo' } }
      let(:expected_message) do
        "Unregistered #{runner.runner_type.chomp('_type')} CI runner. Last contacted #{runner.contacted_at}"
      end

      it 'returns audit event attributes' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(expected_attrs)

        track_event
      end

      context 'with specified token_field' do
        let(:kwargs) do
          { token_field: :runner_registration_token }
        end

        it 'returns audit event attributes' do
          expect(::Gitlab::Audit::Auditor).to receive(:audit).with(expected_attrs)

          track_event
        end

        context 'when author is a token' do
          let(:author) { 'asdfs87rekjh' }
          let(:safe_length) { AuditEvents::SafeRunnerToken::SAFE_TOKEN_LENGTH }
          let(:safe_author) { author[0...safe_length] }

          it 'returns audit event attributes with runner token author and additional details' do
            expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
              expected_attrs.merge(
                author: an_object_having_attributes(
                  name: "Registration token: #{safe_author}",
                  entity_type: scope.class.name,
                  entity_path: scope.full_path),
                additional_details: { runner_registration_token: safe_author })
            )

            track_event
          end

          context 'with registration token prefixed with RUNNERS_TOKEN_PREFIX' do
            let(:author) { "#{::RunnersTokenPrefixable::RUNNERS_TOKEN_PREFIX}b6bce79c3a" }
            let(:safe_length) do
              ::RunnersTokenPrefixable::RUNNERS_TOKEN_PREFIX.length + AuditEvents::SafeRunnerToken::SAFE_TOKEN_LENGTH
            end

            it 'returns audit event attributes with runner token author and additional details' do
              expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
                expected_attrs.merge(
                  author: an_object_having_attributes(
                    name: "Registration token: #{safe_author}",
                    entity_type: scope.class.name,
                    entity_path: scope.full_path),
                  additional_details: { runner_registration_token: safe_author })
              )

              track_event
            end
          end
        end
      end
    end
  end

  describe '#track_event' do
    let(:author) { user }
    let(:expected_scope) { scope }

    subject(:track_event) { service.track_event }

    context 'for instance runner' do
      let_it_be(:runner) { create(:ci_runner, :online, creator_id: owner) }
      let_it_be(:scope) { ::Gitlab::Audit::InstanceScope.new }

      let(:expected_scope) { an_instance_of(::Gitlab::Audit::InstanceScope) }
      let(:target_details) { ::Gitlab::Routing.url_helpers.admin_runner_path(runner) }

      it_behaves_like 'expected audit event'
    end

    context 'for group runner' do
      let_it_be(:scope) { create(:group) }
      let_it_be(:runner) { create(:ci_runner, :group, :online, groups: [scope], creator_id: owner) }

      let(:target_details) { ::Gitlab::Routing.url_helpers.group_runner_path(scope, runner) }

      it_behaves_like 'expected audit event'
    end

    context 'for project runner' do
      let_it_be(:scope) { create(:project) }
      let_it_be(:runner) { create(:ci_runner, :project, :online, projects: [scope], creator_id: owner) }

      let(:target_details) { ::Gitlab::Routing.url_helpers.project_runner_path(scope, runner) }

      it_behaves_like 'expected audit event'
    end
  end
end
