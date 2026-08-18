# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Deployments::HooksWorker, feature_category: :continuous_delivery do
  let(:worker) { described_class.new }

  describe '#perform' do
    let_it_be(:project) { create(:project, :repository) }
    let_it_be(:environment) { create(:environment, project: project) }
    let_it_be(:approver) { create(:user) }
    let_it_be(:deployment) do
      create(:deployment, :blocked, project: project, environment: environment)
    end

    let_it_be(:approval) do
      create(:deployment_approval, deployment: deployment, user: approver)
    end

    let!(:project_hook) { create(:project_hook, project: project, deployment_events: true) }

    context 'when approval and approver ids are provided' do
      let(:params) do
        {
          deployment_id: deployment.id,
          status: approval.status,
          status_changed_at: approval.updated_at.to_s,
          approval_id: approval.id,
          approver_id: approver.id
        }
      end

      it 'dispatches a webhook whose payload carries the approver and approval blocks' do
        expect_next_instance_of(
          WebHookService,
          project_hook,
          hash_including(
            object_kind: 'deployment',
            status: approval.status,
            approver: kind_of(Hash),
            approval: kind_of(Hash)
          ),
          'deployment_hooks',
          idempotency_key: anything
        ) do |service|
          expect(service).to receive(:async_execute)
        end

        worker.perform(params)
      end
    end

    context 'when approval and approver ids are not provided' do
      let(:params) do
        {
          deployment_id: deployment.id,
          status: deployment.status,
          status_changed_at: Time.current.to_s
        }
      end

      it 'dispatches a webhook without the approval metadata' do
        expect_next_instance_of(
          WebHookService,
          project_hook,
          hash_excluding(:approver, :approval),
          'deployment_hooks',
          idempotency_key: anything
        ) do |service|
          expect(service).to receive(:async_execute)
        end

        worker.perform(params)
      end
    end
  end
end
