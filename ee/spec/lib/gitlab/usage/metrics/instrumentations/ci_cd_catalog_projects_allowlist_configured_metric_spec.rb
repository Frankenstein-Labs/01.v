# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::CiCdCatalogProjectsAllowlistConfiguredMetric,
  feature_category: :pipeline_composition do
  using RSpec::Parameterized::TableSyntax

  where(:allowlist, :expected_value) do
    []                     | false
    ['gitlab-org/project'] | true
    ['gitlab-org/.*']      | true
  end

  with_them do
    before do
      stub_application_setting(ci_cd_catalog_projects_allowlist: allowlist)
    end

    it_behaves_like 'a correct instrumented metric value', { time_frame: 'none' }
  end
end
