# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecretDetection::GitlabTokenVerificationWorker, feature_category: :secret_detection do
  describe '#perform' do
    subject(:perform) { described_class.new.perform(pipeline.id) }

    let(:project) { create(:project, :small_repo) }
    let(:pipeline) { create(:ci_pipeline, :success, project: project) }
    let(:service) { instance_double(Security::SecretDetection::UpdateTokenStatusService) }

    before do
      allow(Security::SecretDetection::UpdateTokenStatusService)
        .to receive(:new).and_return(service)
      allow(service).to receive(:execute_for_vulnerability_pipeline)
      allow(service).to receive(:execute_for_security_pipeline)
    end

    context 'when pipeline does not exist' do
      subject(:perform) { described_class.new.perform(non_existing_record_id) }

      it 'does not call the service' do
        perform

        expect(Security::SecretDetection::UpdateTokenStatusService)
          .not_to have_received(:new)
      end
    end

    context 'when pipeline is on the default branch' do
      let(:pipeline) { create(:ci_pipeline, :success, project: project, ref: project.default_branch) }

      it 'delegates to execute_for_vulnerability_pipeline' do
        perform

        expect(Security::SecretDetection::UpdateTokenStatusService)
          .to have_received(:new)
        expect(service).to have_received(:execute_for_vulnerability_pipeline).with(pipeline.id)
        expect(service).not_to have_received(:execute_for_security_pipeline)
      end
    end

    context 'when pipeline is not on the default branch (MR pipeline)' do
      let(:pipeline) { create(:ci_pipeline, :success, project: project, ref: 'feature-branch') }

      it 'delegates to execute_for_security_pipeline' do
        perform

        expect(Security::SecretDetection::UpdateTokenStatusService)
          .to have_received(:new)
        expect(service).to have_received(:execute_for_security_pipeline).with(pipeline.id)
        expect(service).not_to have_received(:execute_for_vulnerability_pipeline)
      end
    end
  end
end
