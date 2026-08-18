# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Ci::PipelineInterface, feature_category: :continuous_integration do
  describe ".resolve_type" do
    using RSpec::Parameterized::TableSyntax

    let_it_be(:pipeline) { create(:ci_pipeline) }

    subject { described_class.resolve_type(pipeline, context) }

    where(:read_pipeline, :read_pipeline_metadata, :resolved_type) do
      false | false | ::Types::Ci::PipelineType
      true  | false | ::Types::Ci::PipelineType
      false | true  | ::Types::Ci::PipelineMinimalAccessType
      true  | true  | ::Types::Ci::PipelineType
    end

    with_them do
      let_it_be(:user) { create(:user) }
      let(:context) { { current_user: user } }

      before do
        allow(user).to receive(:can?).and_call_original
        allow(user).to receive(:can?).with(:read_pipeline, pipeline).and_return(read_pipeline)
        allow(user).to receive(:can?).with(:read_pipeline_metadata, pipeline).and_return(read_pipeline_metadata)
      end

      it { is_expected.to eq resolved_type }
    end

    context 'when current_user is not present' do
      let(:context) { {} }

      it { is_expected.to eq ::Types::Ci::PipelineType }
    end
  end

  it "defines PipelineMinimalAccessType as one of its orphan types" do
    expect(described_class.orphan_types).to include(::Types::Ci::PipelineMinimalAccessType)
  end
end
