# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Deployments::UpdateEnvironmentService, feature_category: :continuous_delivery do
  include ::EE::GeoHelpers

  let_it_be(:project) { create(:project, :repository) }
  # `freeze: false` is required in this spec: one or more `let_it_be` subjects
  # cannot be frozen by default (deep_freeze traversal failure, a non-AR
  # subject, or an in-memory mutation that survives reload/refind). Do not
  # drop these opt-outs or convert them to `let_it_be_with_reload`/`refind`
  # (see gitlab-org/gitlab#602925).
  let_it_be(:deployment, freeze: false) { create(:deployment, :success, project: project) }

  subject { described_class.new(deployment) }

  describe '#execute' do
    context 'when the GitLab instance is a primary Geo site' do
      it 'calls replicator to update Geo' do
        stub_primary_node

        expect(project).to receive(:geo_handle_after_update).once

        subject.execute
      end
    end

    context 'when the GitLab instance is not a primary Geo site' do
      it 'does not call replicator to update Geo' do
        expect(project).not_to receive(:geo_handle_after_update)

        subject.execute
      end
    end

    it 'returns the deployment' do
      expect(subject.execute).to eq(deployment)
    end
  end
end
