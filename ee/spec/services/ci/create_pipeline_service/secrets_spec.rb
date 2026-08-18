# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::CreatePipelineService, feature_category: :secrets_management do
  let(:downstream_project) { create(:project, path: 'project', namespace: create(:namespace, path: 'some')) }

  let_it_be(:project) { create(:project, :repository) }
  let(:user) { project.first_owner }
  let(:service) { described_class.new(project, user, { ref: 'refs/heads/master' }) }

  let(:config) do
    <<~YAML
    test_openbao_direct:
      secrets:
        TEST_SECRET:
          gitlab_secrets_manager:
            name: foo
      script:
      - echo "testing Openbao in CI"
      - cat $TEST_SECRET
      - echo "done."
    YAML
  end

  before do
    downstream_project.add_developer(user)
    stub_ci_pipeline_yaml_file(config)
  end

  it 'persists pipeline' do
    pipeline = create_pipeline!
    expect(pipeline).to be_persisted

    job = pipeline.builds.find_by_name('test_openbao_direct')
    expect(job).not_to be_failed
  end

  def create_pipeline!
    service.execute(:push).payload
  end
end
