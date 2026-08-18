# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::CountProjectsCreatingCiBuildsMetric, feature_category: :product_analytics do
  builds_table_name = Ci::Build.table_name
  colname = 'project_id'

  RSpec.shared_examples 'a correct secure type instrumented metric value' do |params|
    let(:expected_value) { params[:expected_value] }

    before_all do
      project = create(:project)
      project2 = create(:project)

      described_class::SECURE_PRODUCT_TYPES.each do |secure_type|
        create(:ci_build, name: secure_type, project: project, created_at: 3.days.ago)
        create(:ci_build, name: secure_type, project: project)
        create(:ci_build, name: secure_type, project: project2, created_at: 31.days.ago)
      end
    end

    it_behaves_like "with secure type all", described_class, builds_table_name, colname, params

    described_class::SECURE_PRODUCT_TYPES.each do |secure_type|
      it_behaves_like "with secure type", secure_type, params
    end
  end

  it_behaves_like "with time_frame all", builds_table_name, colname

  it_behaves_like 'with time_frame 28d', builds_table_name, colname, :db

  it_behaves_like 'with exception handling'

  it_behaves_like 'with cache', described_class, 'count_projects_creating_ci_builds', ::Project
end
