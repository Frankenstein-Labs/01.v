# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::VulnerabilitiesGradeResolver, feature_category: :vulnerability_management do
  include GraphqlHelpers

  subject(:result) do
    force(resolve(described_class, obj: group, args: args, ctx: { current_user: current_user }))
  end

  let_it_be(:group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: group) }
  let_it_be(:project) { create(:project, namespace: group) }
  let_it_be(:project_in_subgroup) { create(:project, namespace: subgroup) }
  let_it_be(:user) { create(:user) }

  let_it_be(:vulnerability_statistic_1) do
    create(:vulnerability_statistic, :grade_f, project: project)
  end

  let_it_be(:vulnerability_statistic_2) do
    create(:vulnerability_statistic, :grade_d, project: project_in_subgroup)
  end

  let_it_be(:project_with_grade_d) do
    create(:project, namespace: group)
  end

  let_it_be(:vulnerability_statistic_3) do
    create(:vulnerability_statistic, :grade_d, project: project_with_grade_d)
  end

  let(:args) do
    { include_subgroups: include_subgroups, letter_grade: letter_grade }.compact
  end

  let(:current_user) { user }

  shared_examples "returns nil when not allowed" do
    it "returns nil" do
      expect(result).to be_nil
    end
  end

  context "when security dashboards are disabled" do
    before do
      stub_licensed_features(security_dashboard: false)
    end

    let(:include_subgroups) { false }
    let(:letter_grade) { nil }

    include_examples "returns nil when not allowed"
  end

  context "when security dashboards are enabled" do
    before do
      stub_licensed_features(security_dashboard: true)
    end

    context "when user is not logged in" do
      let(:current_user) { nil }
      let(:include_subgroups) { false }
      let(:letter_grade) { nil }

      include_examples "returns nil when not allowed"
    end

    context "when user is logged in" do
      context "when user does not have permissions" do
        let(:include_subgroups) { false }
        let(:letter_grade) { nil }

        include_examples "returns nil when not allowed"
      end

      context "when user has permission to access vulnerabilities" do
        before do
          project.add_developer(current_user)
          group.add_developer(current_user)
          project_with_grade_d.add_developer(current_user)
        end

        describe "#resolve" do
          using RSpec::Parameterized::TableSyntax

          where(:include_subgroups, :letter_grade, :expected_grades) do
            true  | nil | %w[a b c d f]
            true  | :d  | %w[d]
            false | nil | %w[a b c d f]
            false | :d  | %w[d]
          end

          with_them do
            it "returns the correct grades" do
              loaded_result = force(result)

              grades = loaded_result.map(&:grade)

              expect(grades).to match_array(expected_grades)
            end
          end
        end

        describe "#resolve with letter_grade filter" do
          let(:letter_grade) { :d }
          let(:include_subgroups) { true }

          it "returns only the requested grade if it has data" do
            grades = result.map(&:grade)
            expect(grades).to match_array(%w[d])
          end
        end
      end
    end
  end
end
