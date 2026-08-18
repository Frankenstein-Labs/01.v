# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::CiConfigurationService,
  feature_category: :security_policy_management do
  describe '#execute' do
    let_it_be(:project) { create(:project) }
    let_it_be(:template_cache) { Security::SecurityOrchestrationPolicies::TemplateCacheService.new }
    let(:action) { { scan: scan_type } }
    let(:ci_variables) { { KEY: 'value' } }
    let(:context) { 'context' }
    let(:index) { 0 }
    let(:job_name_suffix) { nil }
    let(:opts) do
      {
        template_cache: template_cache,
        job_name_suffix: job_name_suffix
      }
    end

    subject(:execute_service) do
      described_class
        .new(project: project, params: { template_cache: template_cache, job_name_suffix: job_name_suffix })
        .execute(action, ci_variables, context, index)
    end

    shared_examples_for 'a template scan' do
      it 'configures a template scan' do
        expect_next_instance_of(Security::SecurityOrchestrationPolicies::CiAction::Template,
          action,
          ci_variables,
          context,
          index,
          opts
        ) do |instance|
          expect(instance).to receive(:config)
        end

        execute_service
      end
    end

    context 'with secret_detection scan action' do
      let(:scan_type) { 'secret_detection' }

      it_behaves_like 'a template scan'
    end

    context 'with container_scanning scan action' do
      let(:scan_type) { 'container_scanning' }

      it_behaves_like 'a template scan'
    end

    context 'with sast scan action' do
      let(:scan_type) { 'sast' }

      it_behaves_like 'a template scan'
    end

    context 'with sast_iac scan action' do
      let(:scan_type) { 'sast_iac' }

      it_behaves_like 'a template scan'
    end

    context 'with dependency_scanning scan action' do
      let(:scan_type) { 'dependency_scanning' }

      it_behaves_like 'a template scan'
    end

    context 'with unknown action' do
      let(:scan_type) { anything }

      it 'configures a custom scan' do
        expect_next_instance_of(Security::SecurityOrchestrationPolicies::CiAction::Unknown,
          action,
          ci_variables,
          context,
          index,
          opts
        ) do |instance|
          expect(instance).to receive(:config)
        end

        execute_service
      end
    end
  end
end
