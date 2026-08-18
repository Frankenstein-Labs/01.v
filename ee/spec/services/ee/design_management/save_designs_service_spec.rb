# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DesignManagement::SaveDesignsService, feature_category: :design_management do
  include DesignManagementTestHelpers

  # `freeze: false` is required in this spec: one or more `let_it_be` subjects
  # cannot be frozen by default (deep_freeze traversal failure, a non-AR
  # subject, or an in-memory mutation that survives reload/refind). Do not
  # drop these opt-outs or convert them to `let_it_be_with_reload`/`refind`
  # (see gitlab-org/gitlab#602925).
  let_it_be(:project, freeze: false) { create(:project) }
  let_it_be(:issue, freeze: false) { create(:issue, project: project) }
  let_it_be(:user, freeze: false) { create(:user) }
  let_it_be(:design_file, freeze: false) { fixture_file_upload('spec/fixtures/rails_sample.jpg') }
  let_it_be(:design_repository, freeze: false) { project.find_or_create_design_management_repository.repository }

  subject { described_class.new(project, user, issue: issue, files: [design_file]) }

  before do
    enable_design_management
  end

  describe '#execute' do
    before do
      allow_next_instance_of(described_class) do |instance|
        allow(instance).to receive(:repository).and_return(design_repository)
      end
    end

    let(:response) { subject.execute }

    context 'when service is successful' do
      before_all do
        project.add_reporter(user)
      end

      it 'calls repository#log_geo_updated_event', :aggregate_failures do
        expect(design_repository).to receive(:log_geo_updated_event)
        expect(response).to include(status: :success)
      end
    end

    context 'when service errors' do
      it 'does not call repository#log_geo_updated_event', :aggregate_failures do
        expect(design_repository).not_to receive(:log_geo_updated_event)
        expect(response).to include(status: :error)
      end
    end
  end
end
