# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::CreatePipelineService, feature_category: :continuous_integration do # rubocop:disable RSpec/SpecFilePathFormat -- we breakdown Ci::CreatePipelineService E2E tests this way
  let_it_be_with_reload(:project) { create(:project, :small_repo) }
  let(:ref) { 'refs/heads/master' }
  let(:sha) { project.repository.commit(ref).sha }
  let(:service) { described_class.new(project, user, { ref: ref, sha: sha }) }

  subject(:pipeline) { service.execute(:push).payload }

  describe 'composite identity', :request_store do
    let_it_be(:user) { create(:user, :service_account, composite_identity_enforced: true) }
    let_it_be(:scoped_user) { create(:user) }

    before_all do
      project.add_owner(user)
      project.add_maintainer(scoped_user)
      project.update!(allow_composite_identities_to_run_pipelines: true)
    end

    before do
      stub_ci_pipeline_yaml_file(config)

      ::Gitlab::Auth::Identity.fabricate(user).link!(scoped_user)
    end

    context 'when job does not generate options' do
      let(:config) do
        <<~YAML
          build:
            script: echo
            timeout: 1h
          test:
            trigger: test-project
        YAML
      end

      it 'propagates the scoped user into each job without overriding `options`' do
        expect(pipeline).to be_created_successfully
        expect(pipeline.builds).to be_present

        options = pipeline.statuses.map(&:options)
        expect(pipeline.statuses.map(&:scoped_user_id)).to match_array([scoped_user.id, scoped_user.id])
        expect(options).to match_array([
          { script: ['echo'], job_timeout: 1.hour.to_i },
          { trigger: { project: 'test-project' } }
        ])
      end
    end
  end
end
