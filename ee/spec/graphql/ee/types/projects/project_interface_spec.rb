# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Projects::ProjectInterface, feature_category: :groups_and_projects do
  describe ".resolve_type" do
    using RSpec::Parameterized::TableSyntax

    where(:read_project, :read_project_metadata, :resolved_type) do
      false | false | ::Types::ProjectType
      true  | false | ::Types::ProjectType
      false | true  | ::Types::Projects::ProjectMinimalAccessType
      true  | true  | ::Types::ProjectType
    end

    with_them do
      let_it_be(:user) { create(:user) }
      let_it_be(:project) { create(:project) }

      subject { described_class.resolve_type(project, { current_user: user }) }

      before do
        allow(user).to receive(:can?).and_call_original
        allow(user).to receive(:can?).with(:read_project, project).and_return(read_project)
        allow(user).to receive(:can?).with(:read_project_metadata, project).and_return(read_project_metadata)
      end

      it { is_expected.to eq resolved_type }
    end
  end

  it "defines ProjectMinimalAccessType as one of it's orphan types" do
    expect(described_class.orphan_types).to include(::Types::Projects::ProjectMinimalAccessType)
  end
end
