# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Environments::Deployments::AuditService, feature_category: :continuous_delivery do
  let_it_be(:environment) { create(:environment) }

  let(:deployment) { create(:deployment, environment: environment) }

  describe '#execute' do
    subject(:execute) { described_class.new(deployment).execute }

    it 'creates an audit event' do
      allow(environment).to receive(:protected?).and_return(true)

      expect(Gitlab::Audit::Auditor).to receive(:audit).with({
        name: "deployment_started",
        author: deployment.deployed_by,
        scope: deployment.project,
        target: environment,
        message: "Started deployment with IID: #{deployment.iid} and ID: #{deployment.id}"
      })

      expect(execute).to be_a(ServiceResponse)
      expect(execute).to be_success
    end

    context 'when the environment is not protected' do
      it 'does not create an audit event' do
        allow(environment).to receive(:protected?).and_return(false)

        expect(Gitlab::Audit::Auditor).not_to receive(:audit)

        execute
      end
    end
  end
end
