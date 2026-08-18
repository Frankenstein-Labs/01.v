# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::DataBuilder::Deployment, feature_category: :continuous_delivery do
  describe '.build' do
    let_it_be(:project) { create(:project, :repository) }
    let_it_be(:environment) { create(:environment, project: project, name: 'production') }
    let_it_be(:approver) { create(:user) }
    let_it_be(:deployment) do
      create(:deployment, :blocked, environment: environment, project: project)
    end

    context 'when no approval data is provided' do
      it 'omits the approver and approval keys' do
        data = described_class.build(deployment, deployment.status, Time.current)

        expect(data).not_to have_key(:approver)
        expect(data).not_to have_key(:approval)
      end
    end

    context 'when an approval is provided' do
      let_it_be(:approval) do
        create(:deployment_approval,
          deployment: deployment, user: approver, status: :approved, comment: 'LGTM')
      end

      subject(:data) do
        described_class.build(
          deployment,
          approval.status,
          approval.created_at,
          approval: approval,
          approver: approver
        )
      end

      it 'mirrors the approval row in the payload status', :aggregate_failures do
        expect(data[:status]).to eq('approved')
        expect(data[:status_changed_at]).to eq(approval.created_at)
      end

      it 'preserves the deployer in the existing user field' do
        expect(data[:user]).to eq(deployment.deployed_by&.hook_attrs)
      end

      it 'adds top-level approver and approval blocks', :aggregate_failures do
        expect(data[:approver]).to eq(approver.hook_attrs)
        expect(data[:approval]).to eq(approval.hook_attrs)
      end

      it 'preserves CE-defined fields', :aggregate_failures do
        expect(data[:object_kind]).to eq('deployment')
        expect(data[:deployment_id]).to eq(deployment.id)
        expect(data[:environment]).to eq(environment.name)
        expect(data[:project]).to eq(project.hook_attrs)
        expect(data[:ref]).to eq(deployment.ref)
      end

      it 'does not exceed an upper bound on database queries' do
        # Per webhooks.md "Minimizing database requests".
        # Warm the association caches first so the assertion is independent of
        # example ordering: under random order this example may run before the
        # others that would otherwise have warmed the shared let_it_be records.
        described_class.build(
          deployment, approval.status, approval.created_at,
          approval: approval, approver: approver
        )

        recorder = ActiveRecord::QueryRecorder.new do
          described_class.build(
            deployment, approval.status, approval.created_at,
            approval: approval, approver: approver
          )
        end

        expect(recorder.count).to eq(0)
      end
    end

    context 'with a rejected approval' do
      let_it_be(:approval) do
        create(:deployment_approval, :rejected, deployment: deployment, user: approver)
      end

      it 'sets status to "rejected"' do
        data = described_class.build(
          deployment, approval.status, approval.created_at,
          approval: approval, approver: approver
        )

        expect(data[:status]).to eq('rejected')
      end
    end

    context 'when only approver is provided' do
      it 'omits the approval key' do
        data = described_class.build(deployment, deployment.status, Time.current, approver: approver)

        expect(data).to have_key(:approver)
        expect(data).not_to have_key(:approval)
      end
    end

    context 'when only approval is provided' do
      let_it_be(:approval) do
        create(:deployment_approval, deployment: deployment, user: approver)
      end

      it 'omits the approver key' do
        data = described_class.build(
          deployment, approval.status, approval.created_at, approval: approval
        )

        expect(data).to have_key(:approval)
        expect(data).not_to have_key(:approver)
      end
    end
  end
end
