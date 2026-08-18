# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::ConsistencyCheckWorker, feature_category: :vulnerability_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:check_class) { Vulnerabilities::ConsistencyChecks::HasVulnerabilitiesIsCorrectCheck }
  let_it_be(:check_class_name) { check_class.name }
  let_it_be(:project_id) { project.id }

  describe '.perform' do
    subject(:perform) { described_class.new.perform(check_class_name, project_id) }

    it 'executes the check' do
      expect(check_class).to receive(:execute).with(project)

      perform
    end

    context 'when project does not exist' do
      let_it_be(:project_id) { non_existing_record_id }

      it 'does not execute checks' do
        expect(check_class).not_to receive(:execute)

        perform
      end
    end
  end
end
