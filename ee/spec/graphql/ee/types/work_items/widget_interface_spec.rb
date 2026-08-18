# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Types::WorkItems::WidgetInterface, feature_category: :team_planning do
  include GraphqlHelpers
  using RSpec::Parameterized::TableSyntax

  where(:widget_class, :widget_type_name) do
    WorkItems::Widgets::AiSession          | Types::WorkItems::Widgets::AiSessionType
    WorkItems::Widgets::VerificationStatus | Types::WorkItems::Widgets::VerificationStatusType
    WorkItems::Widgets::Weight             | Types::WorkItems::Widgets::WeightType
    WorkItems::Widgets::HealthStatus       | Types::WorkItems::Widgets::HealthStatusType
    WorkItems::Widgets::Progress           | Types::WorkItems::Widgets::ProgressType
    WorkItems::Widgets::Color              | Types::WorkItems::Widgets::ColorType
    WorkItems::Widgets::RequirementLegacy  | Types::WorkItems::Widgets::RequirementLegacyType
    WorkItems::Widgets::TestReports        | Types::WorkItems::Widgets::TestReportsType
    WorkItems::Widgets::Vulnerabilities    | Types::WorkItems::Widgets::VulnerabilitiesType
    WorkItems::Widgets::Status             | Types::WorkItems::Widgets::StatusType
  end

  with_them do
    describe ".resolve_type" do
      it 'knows the correct type for objects' do
        expect(
          described_class.resolve_type(widget_class.new(build(:work_item)), {})
        ).to eq(widget_type_name)
      end

      it 'raises an error for an unknown type' do
        project = build(:project)

        expect { described_class.resolve_type(project, {}) }
          .to raise_error("Unknown GraphQL type for widget #{project}")
      end
    end

    describe '.orphan_types' do
      it 'includes the type' do
        expect(described_class.orphan_types).to include(widget_type_name)
      end
    end
  end
end
