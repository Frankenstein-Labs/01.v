# frozen_string_literal: true

RSpec.shared_examples 'schedules synchronization of vulnerability statistic' do
  it 'sets the resolved vulnerabilities, latest pipeline ID and has_vulnerabilities flag' do
    expect { ingest_reports }.to change { project.reload.project_setting&.has_vulnerabilities }.to(true)
      .and change { project.reload.vulnerability_statistic&.latest_pipeline_id }.to(latest_pipeline.id)
  end
end
