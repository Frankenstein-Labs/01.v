# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Ci::JobInterface, feature_category: :continuous_integration do
  describe ".resolve_type" do
    using RSpec::Parameterized::TableSyntax

    where(:read_build, :read_build_metadata, :resolved_type) do
      false | false | ::Types::Ci::JobType
      true  | false | ::Types::Ci::JobType
      false | true  | ::Types::Ci::JobMinimalAccessType
      true  | true  | ::Types::Ci::JobType
    end

    with_them do
      let_it_be(:user) { create(:user) }
      let_it_be(:build) { create(:ci_build) }

      subject { described_class.resolve_type(build, { current_user: user }) }

      before do
        allow(user).to receive(:can?).and_call_original
        allow(user).to receive(:can?).with(:read_build, build).and_return(read_build)
        allow(user).to receive(:can?).with(:read_build_metadata, build).and_return(read_build_metadata)
      end

      it { is_expected.to eq resolved_type }
    end
  end

  it "defines JobMinimalAccessType as one of it's orphan types" do
    expect(described_class.orphan_types).to include(::Types::Ci::JobMinimalAccessType)
  end
end
