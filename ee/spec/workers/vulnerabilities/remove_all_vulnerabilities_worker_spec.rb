# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::RemoveAllVulnerabilitiesWorker, feature_category: :vulnerability_management do
  let_it_be(:project) { create(:project) }

  describe "#perform" do
    let(:batch_size) { 1 }
    let(:worker) { described_class.new }
    let(:mock_service_instance) { instance_double(Vulnerabilities::Removal::RemoveFromProjectService, execute: true) }

    before do
      allow(Vulnerabilities::Removal::RemoveFromProjectService).to receive(:new).and_return(mock_service_instance)
    end

    include_examples 'an idempotent worker' do
      subject(:perform) { worker.perform(project.id, { 'resolved_on_default_branch' => true }) }

      it 'delegates the call to `Vulnerabilities::Removal::RemoveFromProjectService`' do
        perform

        expect(Vulnerabilities::Removal::RemoveFromProjectService)
          .to have_received(:new).with(project, { resolved_on_default_branch: true })

        expect(mock_service_instance).to have_received(:execute)
      end

      context 'when the worker receives a non-existing project ID' do
        subject(:perform) { worker.perform(non_existing_record_id) }

        it 'does not call the service logic' do
          perform

          expect(Vulnerabilities::Removal::RemoveFromProjectService).not_to have_received(:new)
        end
      end
    end
  end
end
