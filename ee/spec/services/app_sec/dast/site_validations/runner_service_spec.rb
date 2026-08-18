# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AppSec::Dast::SiteValidations::RunnerService do
  let_it_be_with_reload(:project) { create(:project, :small_repo) }
  let_it_be(:developer) { create(:user, developer_of: project) }
  let_it_be(:dast_site_token) { create(:dast_site_token, project: project) }
  let_it_be_with_reload(:dast_site_validation) { create(:dast_site_validation, dast_site_token: dast_site_token) }
  let_it_be(:default_runner) { create(:ci_runner, :project, projects: [project], run_untagged: true) }

  subject do
    described_class.new(project: project, current_user: developer, params: { dast_site_validation: dast_site_validation }).execute
  end

  before_all do
    project.update!(ci_pipeline_variables_minimum_override_role: :developer)
  end

  before do
    # Grant admin permissions to avoid access denied errors in Ci::RunnersFinder
    allow(Ability).to receive(:allowed?).and_call_original
    allow(Ability).to receive(:allowed?).with(developer, :read_admin_cicd).and_return(true)
    allow(Ability).to receive(:allowed?).with(developer, :read_runners, project).and_return(true)
  end

  describe 'execute' do
    shared_examples 'a failure' do
      it 'communicates failure' do
        aggregate_failures do
          expect(subject.status).to eq(:error)
          expect(subject.message).to eq('Insufficient permissions')
        end
      end
    end

    context 'when on demand scan licensed feature is not available' do
      before do
        stub_licensed_features(security_on_demand_scans: false)
      end

      it_behaves_like 'a failure'
    end

    context 'when the feature is enabled' do
      before do
        stub_licensed_features(security_on_demand_scans: true)
      end

      it 'is allowed to set pipeline variables regardless of minimum override role' do
        project.update!(ci_pipeline_variables_minimum_override_role: :maintainer)

        expect(developer.can?(:set_pipeline_variables, project)).to be false
        expect(subject).to be_success
      end

      it 'communicates success, creates a ci_pipeline with an appropriate source, and exposes build variables',
        :aggregate_failures do
        expect { subject }.to change { Ci::Pipeline.count }.by(1)

        expect(subject).to have_attributes(status: :success, payload: dast_site_validation)

        pipeline = Ci::Pipeline.last
        expect(pipeline.source).to eq('ondemand_dast_validation')

        build = pipeline.builds.find_by(name: 'validation')

        expected_variables = {
          'DAST_SITE_VALIDATION_ID' => String(dast_site_validation.id),
          'DAST_SITE_VALIDATION_HEADER' => ::DastSiteValidation::HEADER,
          'DAST_SITE_VALIDATION_STRATEGY' => dast_site_validation.validation_strategy,
          'DAST_SITE_VALIDATION_TOKEN' => dast_site_validation.dast_site_token.token,
          'DAST_SITE_VALIDATION_URL' => dast_site_validation.validation_url
        }

        expect(build.variables.to_hash).to include(expected_variables)
      end

      context 'when FIPS mode is enabled' do
        it 'adds the correct image suffix' do
          allow(::Gitlab::FIPS).to receive(:enabled?).and_return(true)
          subject

          build = Ci::Pipeline.last.builds.find_by(name: 'validation')

          expect(build.variables.to_hash).to include({ DAST_IMAGE_SUFFIX: "-fips" })
        end
      end

      context 'when FIPS mode is disabled' do
        it 'adds the correct image suffix' do
          allow(::Gitlab::FIPS).to receive(:enabled?).and_return(false)
          subject

          build = Ci::Pipeline.last.builds.find_by(name: 'validation')

          expect(build.variables.to_hash).to include({ DAST_IMAGE_SUFFIX: "" })
        end
      end

      context 'when no suitable runners are available' do
        before do
          allow_next_instance_of(described_class) do |instance|
            allow(instance).to receive(:available_runners_exist?).and_return(false)
          end
        end

        it 'returns an error' do
          expect(subject).to have_attributes(
            status: :error,
            message: 'No suitable runners available for DAST validation'
          )
        end
      end

      context 'when tagged runners are available' do
        let_it_be(:ci_tag) { create(:ci_tag, name: 'dast-validation-runner') }
        let_it_be(:tagged_runner) { create(:ci_runner, :project, projects: [project]) }

        before_all do
          # Create the runner-tag association (avoid duplicates)
          unless tagged_runner.taggings.joins(:tag).where(tags: { name: ci_tag.name }).exists?
            create(:ci_runner_tagging, runner: tagged_runner, tag: ci_tag)
          end
        end

        it 'creates pipeline with tagged configuration' do
          expect { subject }.to change { Ci::Pipeline.count }.by(1)

          pipeline = Ci::Pipeline.last
          expect(pipeline.source).to eq('ondemand_dast_validation')
        end

        it 'sets tags in ci_configuration' do
          service = described_class.new(project: project, current_user: developer, params: { dast_site_validation: dast_site_validation })
          config = service.send(:ci_configuration)
          expect(config['validation']['tags']).to eq(['dast-validation-runner'])
        end
      end

      context 'when only untagged runners are available' do
        it 'creates pipeline without tags configuration' do
          expect { subject }.to change { Ci::Pipeline.count }.by(1)

          pipeline = Ci::Pipeline.last
          expect(pipeline.source).to eq('ondemand_dast_validation')
        end

        it 'does not set validation entry in ci_configuration' do
          service = described_class.new(project: project, current_user: developer, params: { dast_site_validation: dast_site_validation })
          config = service.send(:ci_configuration)
          expect(config).not_to have_key('validation')
        end
      end

      context 'when both tagged and untagged runners are available' do
        let(:ci_tag_2) { create(:ci_tag, name: 'dast-validation-runner') }
        let(:tagged_runner_2) { create(:ci_runner, :project, projects: [project]) }

        before do
          # Create the runner-tag association (avoid duplicates)
          unless tagged_runner_2.taggings.joins(:tag).where(tags: { name: ci_tag_2.name }).exists?
            create(:ci_runner_tagging, runner: tagged_runner_2, tag: ci_tag_2)
          end
        end

        it 'prioritizes tagged runners and sets tags in configuration' do
          service = described_class.new(project: project, current_user: developer, params: { dast_site_validation: dast_site_validation })
          config = service.send(:ci_configuration)

          expect(config['validation']['tags']).to eq(['dast-validation-runner'])
        end
      end

      context 'when pipeline creation fails' do
        before do
          # Mock successful Ci::CreatePipelineService result but failed pipeline
          allow_next_instance_of(Ci::CreatePipelineService) do |instance|
            mock_result = instance_double(ServiceResponse, success?: false)
            allow(instance).to receive(:execute).and_return(mock_result)
          end
        end

        it 'transitions the dast_site_validation to a failure state', :aggregate_failures do
          expect(dast_site_validation).to receive(:fail_op).and_call_original

          expect { subject }.to change { dast_site_validation.state }.from('pending').to('failed')
        end
      end
    end
  end
end
