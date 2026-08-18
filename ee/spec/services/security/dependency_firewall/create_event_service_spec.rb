# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::DependencyFirewall::CreateEventService, feature_category: :dependency_firewall do
  let_it_be(:project) { create(:project) }
  let_it_be(:namespace) { project.namespace }

  let(:enforcement) { Security::DependencyFirewall::EnforcementService }
  let(:operation) { described_class::PACKAGE_DOWNLOAD }
  let(:outcome) { enforcement::SUCCESS_ALLOWED }
  let(:purl) { 'pkg:npm/lodash@4.17.21' }
  let(:cache_hit) { false }
  let(:runtime_ms) { 42 }

  let(:params) do
    {
      operation: operation,
      outcome: outcome,
      namespace: namespace,
      purl: purl,
      cache_hit: cache_hit,
      runtime_ms: runtime_ms
    }
  end

  subject(:service) { described_class.new(project, nil, params) }

  describe '#execute' do
    context 'when translating outcome to label in additional_properties' do
      where(:outcome, :expected_label) do
        e = Security::DependencyFirewall::EnforcementService
        [
          [e::SUCCESS_ALLOWED, 'allowed'],
          [e::SUCCESS_BLOCKED, 'blocked-license'],
          [e::SUCCESS_WARNING, 'warn-license']
        ]
      end

      with_them do
        it 'sets the correct label' do
          expect { service.execute }
            .to trigger_internal_events(
              'collect_dependency_firewall_metrics_on_package_download_from_package_registry'
            )
            .with(project: project, namespace: namespace,
              additional_properties: { label: expected_label, property: "0", value: runtime_ms, purl: purl })
        end
      end
    end

    context 'when operation is valid' do
      it 'tracks the correct event with all parameters' do
        expect { service.execute }
          .to trigger_internal_events(
            'collect_dependency_firewall_metrics_on_package_download_from_package_registry'
          )
          .with(
            user: nil,
            project: project,
            namespace: namespace,
            additional_properties: { label: 'allowed', property: "0", value: runtime_ms, purl: purl }
          )
      end

      context 'with cache hit' do
        let(:cache_hit) { true }

        it 'sets property to "1"' do
          expect { service.execute }
            .to trigger_internal_events(
              'collect_dependency_firewall_metrics_on_package_download_from_package_registry'
            )
            .with(project: project, namespace: namespace,
              additional_properties: { label: 'allowed', property: "1", value: runtime_ms, purl: purl })
        end
      end

      context 'with container pull operation' do
        let(:operation) { described_class::CONTAINER_PULL }
        let(:purl) { 'pkg:docker/cassandra@sha256:244fd47e07d1004f0aed9c' }

        it 'tracks the container pull event with purl in additional_properties' do
          expect { service.execute }
            .to trigger_internal_events(
              'collect_dependency_firewall_metrics_on_image_pull_from_container_registry'
            )
            .with(project: project, namespace: namespace,
              additional_properties: { label: 'allowed', property: "0", value: runtime_ms, purl: purl })
        end
      end

      context 'with forwarded package download' do
        let(:operation) { described_class::PACKAGE_FORWARDED }

        it 'tracks the forwarded download event' do
          expect { service.execute }
            .to trigger_internal_events(
              'collect_dependency_firewall_metrics_on_forwarded_package_download_from_package_registry'
            )
            .with(user: nil, project: project, namespace: namespace,
              additional_properties: { label: 'allowed', property: "0", value: runtime_ms, purl: purl })
        end
      end

      context 'with package upload operation' do
        let(:operation) { described_class::PACKAGE_UPLOAD }

        it 'tracks the package upload event' do
          expect { service.execute }
            .to trigger_internal_events(
              'collect_dependency_firewall_metrics_on_package_upload_to_package_registry'
            )
            .with(user: nil, project: project, namespace: namespace,
              additional_properties: { label: 'allowed', property: "0", value: runtime_ms, purl: purl })
        end
      end

      context 'with container push operation' do
        let(:operation) { described_class::CONTAINER_PUSH }
        let(:purl) { 'pkg:docker/my-app@sha256:a1b2c3d4e5f6' }

        it 'tracks the container push event with purl in additional_properties' do
          expect { service.execute }
            .to trigger_internal_events(
              'collect_dependency_firewall_metrics_on_image_push_to_container_registry'
            )
            .with(project: project, namespace: namespace,
              additional_properties: { label: 'allowed', property: "0", value: runtime_ms, purl: purl })
        end
      end
    end

    context 'when current_user is a User' do
      let_it_be(:user) { create(:user) }

      subject(:service) { described_class.new(project, user, params) }

      it 'forwards the user to the internal-events tracker' do
        expect { service.execute }
          .to trigger_internal_events(
            'collect_dependency_firewall_metrics_on_package_download_from_package_registry'
          )
          .with(
            user: user,
            project: project,
            namespace: namespace,
            additional_properties: { label: 'allowed', property: '0', value: runtime_ms, purl: purl }
          )
      end
    end

    context 'when current_user is a DeployToken' do
      # Regression for https://gitlab.com/gitlab-org/gitlab/-/work_items/606353:
      # Gitlab::Tracking::EventValidator rejects non-User values on the :user key,
      # so tracking must fall back to :user=>nil when a deploy token is the actor
      # (CI_JOB_TOKEN, deploy-token package requests, etc.).
      let_it_be(:deploy_token) { create(:deploy_token) }

      subject(:service) { described_class.new(project, deploy_token, params) }

      it 'omits the user and still tracks the event' do
        expect { service.execute }
          .to trigger_internal_events(
            'collect_dependency_firewall_metrics_on_package_download_from_package_registry'
          )
          .with(
            user: nil,
            project: project,
            namespace: namespace,
            additional_properties: { label: 'allowed', property: '0', value: runtime_ms, purl: purl }
          )
      end

      it 'does not raise InvalidPropertyTypeError' do
        expect { service.execute }.not_to raise_error
      end
    end

    context 'when operation is invalid' do
      let(:operation) { 999 }

      it 'logs a warning and does not track an event' do
        expect(Gitlab::AppLogger).to receive(:warn).with(/unknown operation/)
        expect { service.execute }.not_to trigger_internal_events
      end
    end
  end

  describe '#outcome_label' do
    it 'raises on unknown outcome' do
      expect { service.send(:outcome_label, :unknown) }
        .to raise_error(ArgumentError, /unknown outcome/)
    end
  end
end
