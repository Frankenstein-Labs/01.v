# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::DependencyFirewall::CreateAuditEventsService, feature_category: :dependency_firewall do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }

  let(:purl) { 'pkg:npm/lodash@4.17.21' }
  let(:operation) { Security::DependencyFirewall::EnforcementService::PACKAGE_DOWNLOAD }
  let(:result) { {} }
  let(:event_type) { :allowed }

  subject(:service) do
    described_class.new(
      project: project,
      purl: purl,
      operation: operation,
      result: result,
      author: user,
      event_type: event_type
    )
  end

  def build_rule(attributes)
    Security::DependencyFirewallPolicies::Rule.by_type(attributes)
  end

  describe '#execute' do
    context 'when project is nil' do
      subject(:service) do
        described_class.new(
          project: nil, purl: purl, operation: operation,
          result: result, author: user, event_type: :allowed
        )
      end

      it 'does nothing' do
        expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

        service.execute
      end
    end

    context 'when event_type is :allowed' do
      let(:event_type) { :allowed }

      it 'creates a dependency_firewall_allowed audit event' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(
            name: 'dependency_firewall_allowed',
            author: user,
            scope: project,
            target: project,
            message: "Allowed package download for dependency #{purl}",
            additional_details: hash_including(
              purl: purl,
              operation: 'package download',
              matched_rule: nil,
              policy_name: nil,
              policies_evaluated: nil
            )
          )
        )

        service.execute
      end
    end

    context 'when allowed because a user bypassed the policy' do
      let(:event_type) { :allowed }
      let(:result) { { reason: :user_bypassed, policy_name: 'Block Copyleft' } }

      it 'notes the user bypass and the policy in the message' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(
            message: %(Allowed package download for dependency #{purl} (bypassed by user via "Block Copyleft"))
          )
        )

        service.execute
      end
    end

    context 'when allowed because an access token bypassed the policy' do
      let(:event_type) { :allowed }
      let(:result) { { reason: :token_bypassed, policy_name: 'Block Copyleft' } }

      it 'notes the access token bypass and the policy in the message' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(
            message: %(Allowed package download for dependency #{purl} (bypassed by access token via "Block Copyleft"))
          )
        )

        service.execute
      end
    end

    context 'when allowed because the purl is in the policy exceptions' do
      let(:event_type) { :allowed }
      let(:result) { { reason: :exception, policy_name: 'Block Copyleft' } }

      it 'notes the exception and the policy in the message' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(
            message: %(Allowed package download for dependency #{purl} (allowed by "Block Copyleft" exception))
          )
        )

        service.execute
      end
    end

    context 'when allowed for a non-notable reason' do
      let(:event_type) { :allowed }
      let(:result) { { reason: :evaluation, policy_name: 'Block Copyleft' } }

      it 'uses the generic allowed message without a reason suffix' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(message: "Allowed package download for dependency #{purl}")
        )

        service.execute
      end
    end

    context 'when event_type is :blocked' do
      let(:event_type) { :blocked }
      let(:matched_rule_attributes) do
        { type: 'license', denied: [{ name: 'GPL-3.0-only' }, { name: 'AGPL-3.0-only' }] }
      end

      let(:result) do
        {
          policy_name: 'Block Copyleft',
          matched_rule: build_rule(matched_rule_attributes),
          policies_evaluated: 1
        }
      end

      it 'creates a dependency_firewall_blocked audit event' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(name: 'dependency_firewall_blocked')
        )

        service.execute
      end

      it 'includes matched_rule and policy_name in additional_details' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(
            additional_details: hash_including(
              policy_name: 'Block Copyleft',
              matched_rule: matched_rule_attributes
            )
          )
        )

        service.execute
      end

      it 'builds a message describing the denied licenses' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(
            message: "Blocked package download for dependency #{purl} " \
              "due to Block Copyleft violation (licenses: GPL-3.0-only, AGPL-3.0-only)"
          )
        )

        service.execute
      end
    end

    context 'when event_type is :warned' do
      let(:event_type) { :warned }
      let(:result) do
        {
          policy_name: 'Advisory Policy',
          matched_rule: build_rule({ type: 'license', denied: [{ name: 'Apache-2.0' }] })
        }
      end

      it 'creates a dependency_firewall_warned audit event' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(name: 'dependency_firewall_warned')
        )

        service.execute
      end

      it 'builds an advisory message with the denied license' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(
            message: "Warning: policy matched for package download of dependency #{purl} " \
              "(Advisory Policy) (licenses: Apache-2.0)"
          )
        )

        service.execute
      end
    end

    context 'when a license rule matches via an allowed-list (no denied licenses)' do
      let(:result) do
        {
          policy_name: 'Allow permissive licenses',
          matched_rule: build_rule({ type: 'license', allowed: [{ name: 'MIT' }] })
        }
      end

      where(:event_type, :expected_message) do
        [
          [:blocked, "Blocked package download for dependency %{purl} due to Allow permissive licenses violation"],
          [:warned,  "Warning: policy matched for package download of dependency %{purl} (Allow permissive licenses)"]
        ]
      end

      with_them do
        it 'omits the licenses suffix instead of rendering an empty one' do
          expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
            hash_including(message: format(expected_message, purl: purl))
          )

          service.execute
        end
      end
    end

    context 'when a vulnerability rule blocks' do
      let(:event_type) { :blocked }
      let(:result) do
        {
          policy_name: 'Block vulnerabilities',
          matched_rule: build_rule({ type: 'vulnerability', denied: [{ severity: 'low' }] })
        }
      end

      it 'builds a message describing the matched severity' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(
            message: "Blocked package download for dependency #{purl} " \
              "due to Block vulnerabilities violation (matched severity: low)"
          )
        )

        service.execute
      end
    end

    context 'when a vulnerability rule warns' do
      let(:event_type) { :warned }
      let(:result) do
        {
          policy_name: 'Allow vulnerabilities',
          matched_rule: build_rule({ type: 'vulnerability', allowed: [{ severity: 'high' }] })
        }
      end

      it 'builds an advisory message describing the matched severity' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(
            message: "Warning: policy matched for package download of dependency #{purl} " \
              "(Allow vulnerabilities) (matched severity: high)"
          )
        )

        service.execute
      end
    end

    context 'when a vulnerability rule warns via a denying rule' do
      let(:event_type) { :warned }
      let(:result) do
        {
          policy_name: 'Block vulnerabilities',
          matched_rule: build_rule({ type: 'vulnerability', denied: [{ severity: 'low' }] })
        }
      end

      it 'uses a neutral severity label inside the advisory message' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(
            message: "Warning: policy matched for package download of dependency #{purl} " \
              "(Block vulnerabilities) (matched severity: low)"
          )
        )

        service.execute
      end
    end

    context 'when a vulnerability rule has no severity detail' do
      let(:event_type) { :blocked }
      let(:result) do
        {
          policy_name: 'Block vulnerabilities',
          matched_rule: build_rule({ type: 'vulnerability', denied: [{}] })
        }
      end

      it 'omits the rule detail suffix' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(
            message: "Blocked package download for dependency #{purl} due to Block vulnerabilities violation"
          )
        )

        service.execute
      end
    end

    context 'when event_type is unknown' do
      let(:event_type) { :unknown_type }

      before do
        allow(::Gitlab::ErrorTracking).to receive(:track_exception)
      end

      it 'does not audit' do
        expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

        service.execute
      end

      it 'tracks an ArgumentError' do
        service.execute

        expect(::Gitlab::ErrorTracking).to have_received(:track_exception)
          .with(an_instance_of(ArgumentError), project_id: project.id, purl: purl)
      end
    end

    context 'when author is nil' do
      subject(:service) do
        described_class.new(
          project: project, purl: purl, operation: operation,
          result: result, author: nil, event_type: :allowed
        )
      end

      it 'falls back to UnauthenticatedAuthor' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(author: an_instance_of(::Gitlab::Audit::UnauthenticatedAuthor))
        )

        service.execute
      end
    end

    context 'with operation labels' do
      where(:op_constant, :expected_label) do
        [
          [Security::DependencyFirewall::EnforcementService::PACKAGE_DOWNLOAD, 'package download'],
          [Security::DependencyFirewall::EnforcementService::PACKAGE_UPLOAD,   'package upload'],
          [Security::DependencyFirewall::EnforcementService::CONTAINER_PULL,   'container pull'],
          [Security::DependencyFirewall::EnforcementService::CONTAINER_PUSH,   'container push']
        ]
      end

      with_them do
        it 'uses the correct label in additional_details' do
          expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
            hash_including(additional_details: hash_including(operation: expected_label))
          )

          described_class.new(
            project: project, purl: purl, operation: op_constant,
            result: result, author: user, event_type: :allowed
          ).execute
        end
      end
    end

    context 'when Auditor raises an error' do
      before do
        allow(::Gitlab::Audit::Auditor).to receive(:audit).and_raise(StandardError, 'audit failed')
        allow(::Gitlab::ErrorTracking).to receive(:track_exception)
      end

      it 'does not propagate the error' do
        expect { service.execute }.not_to raise_error
      end

      it 'tracks the exception' do
        service.execute

        expect(::Gitlab::ErrorTracking).to have_received(:track_exception)
          .with(an_instance_of(StandardError), project_id: project.id, purl: purl)
      end
    end
  end
end
