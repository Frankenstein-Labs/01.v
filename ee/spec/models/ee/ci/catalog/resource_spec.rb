# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::Catalog::Resource, feature_category: :pipeline_composition do
  let_it_be(:project) { create(:project) }
  # `freeze: false` is required in this spec: one or more `let_it_be` subjects
  # cannot be frozen by default (deep_freeze traversal failure, a non-AR
  # subject, or an in-memory mutation that survives reload/refind). Do not
  # drop these opt-outs or convert them to `let_it_be_with_reload`/`refind`
  # (see gitlab-org/gitlab#602925).
  let_it_be(:ci_catalog_resource, freeze: false) { build(:ci_catalog_resource, project: project) }

  describe 'elasticsearch indexing' do
    before do
      allow(project).to receive(:maintaining_elasticsearch?).and_return(true)
    end

    context 'when updating a catalog resource' do
      it 'calls maintain_elasticsearch_update' do
        expect(project).to receive(:maintain_elasticsearch_update)

        ci_catalog_resource.save!
      end
    end
  end
end
