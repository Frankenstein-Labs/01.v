# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Variables::Builder, feature_category: :pipeline_composition do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, namespace: group) }
  let_it_be_with_reload(:pipeline) { create(:ci_pipeline, project: project) }
  let_it_be(:user) { create(:user) }
  let_it_be(:yaml_variables) { [{ key: 'YAML_VARIABLE', value: 'value' }] }
  let_it_be_with_reload(:job) do
    create(:ci_build,
      :with_deployment,
      name: 'rspec:test 1',
      pipeline: pipeline,
      user: user,
      yaml_variables: yaml_variables,
      environment: 'review/$CI_COMMIT_REF_NAME',
      options: {
        environment: {
          name: 'review/$CI_COMMIT_REF_NAME',
          action: 'prepare',
          deployment_tier: 'testing',
          url: 'https://gitlab.com'
        }
      }
    )
  end

  let(:builder) { described_class.new(pipeline) }

  describe '#scoped_variables' do
    let(:environment_name) { job.expanded_environment_name }
    let(:dependencies) { true }

    subject(:scoped_variables) do
      builder.scoped_variables(job,
        environment: environment_name, dependencies: dependencies
      )
    end

    it { is_expected.to be_instance_of(Gitlab::Ci::Variables::Collection) }

    describe 'variables ordering' do
      before do
        pipeline_variables_builder = instance_double(
          ::Gitlab::Ci::Variables::Builder::Pipeline,
          predefined_variables: [var('C', 3), var('D', 3)]
        )

        allow(builder).to receive(:predefined_variables) { [var('A', 1), var('B', 1)] }
        allow(pipeline.project).to receive(:predefined_variables) { [var('B', 2), var('C', 2)] }
        allow(builder).to receive(:pipeline_variables_builder) { pipeline_variables_builder }
        allow(pipeline).to receive(:predefined_variables) { [var('C', 3), var('D', 3)] }
        allow(builder).to receive(:predefined_traceparent_variables).with(job).and_return([])
        allow(job).to receive(:runner) do
          instance_double(::Ci::Runner, predefined_variables: [var('D', 4), var('E', 4)])
        end
        allow(builder).to receive(:kubernetes_variables) { [var('E', 5), var('F', 5)] }
        allow(job).to receive(:yaml_variables) { [var('G', 7), var('H', 7)] }
        allow(builder).to receive(:user_variables) { [var('H', 8), var('I', 8)] }
        allow(job).to receive(:dependency_variables) { [var('I', 9), var('J', 9)] }
        allow(builder).to receive(:secret_instance_variables) { [var('J', 10), var('K', 10)] }
        allow(builder).to receive(:secret_group_variables) { [var('K', 11), var('L', 11)] }
        allow(builder).to receive(:secret_project_variables) { [var('L', 12), var('M', 12)] }
        allow(pipeline).to receive(:variables) { [var('M', 13), var('N', 13)] }
        allow(pipeline).to receive(:pipeline_schedule) do
          instance_double(::Ci::PipelineSchedule, job_variables: [var('N', 14), var('O', 14)])
        end
        allow(builder).to receive(:release_variables) { [var('P', 15), var('Q', 15)] }
      end

      it 'returns variables in order depending on resource hierarchy' do
        expect(scoped_variables.to_hash_variables).to eq(
          [var('A', 1), var('B', 1),
            var('B', 2), var('C', 2),
            var('C', 3), var('D', 3),
            var('D', 4), var('E', 4),
            var('E', 5), var('F', 5),
            var('G', 7), var('H', 7),
            var('H', 8), var('I', 8),
            var('I', 9), var('J', 9),
            var('J', 10), var('K', 10),
            var('K', 11), var('L', 11),
            var('L', 12), var('M', 12),
            var('M', 13), var('N', 13),
            var('N', 14), var('O', 14),
            var('P', 15), var('Q', 15)])
      end

      it 'overrides duplicate keys depending on resource hierarchy' do
        expect(scoped_variables.to_hash).to match(
          'A' => '1', 'B' => '2',
          'C' => '3', 'D' => '4',
          'E' => '5', 'F' => '5',
          'G' => '7', 'H' => '8',
          'I' => '9', 'J' => '10',
          'K' => '11', 'L' => '12',
          'M' => '13', 'N' => '14',
          'O' => '14', 'P' => '15',
          'Q' => '15')
      end

      context 'when using legacy SEP variables builder' do
        let(:builder) { described_class.new(pipeline) }

        before do
          scan_execution_policies_variables_builder = instance_double(
            ::EE::Gitlab::Ci::Variables::Builder::ScanExecutionPolicies,
            variables: [var('Q', 16), var('R', 16)]
          )
          allow(builder).to receive(:scan_execution_policies_variables_builder) do
            scan_execution_policies_variables_builder
          end
        end

        context 'when job does not have policy metadata' do
          it 'appends old SEP builder variables at the end of the chain' do
            expect(scoped_variables.to_hash_variables).to eq(
              [var('A', 1), var('B', 1),
                var('B', 2), var('C', 2),
                var('C', 3), var('D', 3),
                var('D', 4), var('E', 4),
                var('E', 5), var('F', 5),
                var('G', 7), var('H', 7),
                var('H', 8), var('I', 8),
                var('I', 9), var('J', 9),
                var('J', 10), var('K', 10),
                var('K', 11), var('L', 11),
                var('L', 12), var('M', 12),
                var('M', 13), var('N', 13),
                var('N', 14), var('O', 14),
                var('P', 15), var('Q', 15),
                var('Q', 16), var('R', 16)])
          end

          it 'overrides duplicate keys with old SEP builder variables' do
            expect(scoped_variables.to_hash).to match(
              'A' => '1', 'B' => '2',
              'C' => '3', 'D' => '4',
              'E' => '5', 'F' => '5',
              'G' => '7', 'H' => '8',
              'I' => '9', 'J' => '10',
              'K' => '11', 'L' => '12',
              'M' => '13', 'N' => '14',
              'O' => '14', 'P' => '15',
              'Q' => '16', 'R' => '16')
          end
        end

        context 'when job has policy metadata but no variables_override (FF disabled)' do
          before do
            stub_ci_job_definition(job, options: job.options.merge(policy: { name: 'Policy' }))
          end

          it 'still appends old SEP builder variables' do
            expect(scoped_variables.to_hash_variables).to eq(
              [var('A', 1), var('B', 1),
                var('B', 2), var('C', 2),
                var('C', 3), var('D', 3),
                var('D', 4), var('E', 4),
                var('E', 5), var('F', 5),
                var('G', 7), var('H', 7),
                var('H', 8), var('I', 8),
                var('I', 9), var('J', 9),
                var('J', 10), var('K', 10),
                var('K', 11), var('L', 11),
                var('L', 12), var('M', 12),
                var('M', 13), var('N', 13),
                var('N', 14), var('O', 14),
                var('P', 15), var('Q', 15),
                var('Q', 16), var('R', 16)])
          end

          it 'overrides duplicate keys with old SEP builder variables' do
            expect(scoped_variables.to_hash).to match(
              'A' => '1', 'B' => '2',
              'C' => '3', 'D' => '4',
              'E' => '5', 'F' => '5',
              'G' => '7', 'H' => '8',
              'I' => '9', 'J' => '10',
              'K' => '11', 'L' => '12',
              'M' => '13', 'N' => '14',
              'O' => '14', 'P' => '15',
              'Q' => '16', 'R' => '16')
          end
        end
      end

      context 'when job is marked as a pipeline execution policy job' do
        before do
          stub_ci_job_definition(job, options:
            job.options.merge(policy: { name: 'Policy', pipeline_execution_policy_job: true })
          )
        end

        it 'replaces yaml_variables to apply them with the highest precedence' do
          expect(scoped_variables.to_hash_variables).to eq(
            [var('A', 1), var('B', 1),
              var('B', 2), var('C', 2),
              var('C', 3), var('D', 3),
              var('D', 4), var('E', 4),
              var('E', 5), var('F', 5),
              var('I', 8),
              var('I', 9), var('J', 9),
              var('J', 10), var('K', 10),
              var('K', 11), var('L', 11),
              var('L', 12), var('M', 12),
              var('M', 13), var('N', 13),
              var('N', 14), var('O', 14),
              var('P', 15), var('Q', 15),
              var('G', 7), var('H', 7)])
        end

        it 'overrides duplicate keys depending on resource hierarchy' do
          expect(scoped_variables.to_hash).to match(
            'A' => '1', 'B' => '2',
            'C' => '3', 'D' => '4',
            'E' => '5', 'F' => '5',
            'G' => '7', 'H' => '7',
            'I' => '9', 'J' => '10',
            'K' => '11', 'L' => '12',
            'M' => '13', 'N' => '14',
            'O' => '14', 'P' => '15',
            'Q' => '15')
        end

        context 'when job has variables_override option set to disallow user-defined variables' do
          before do
            stub_ci_job_definition(job, options:
              job.options.merge(policy: { name: 'Policy', variables_override: { allowed: false } })
            )
          end

          it 'returns variables without user-defined variables' do
            expect(scoped_variables.to_hash_variables).to eq(
              [var('A', 1), var('B', 1),
                var('B', 2), var('C', 2),
                var('C', 3), var('D', 3),
                var('D', 4), var('E', 4),
                var('E', 5), var('F', 5),
                var('G', 7), var('H', 7),
                var('H', 8), var('I', 8),
                var('I', 9), var('J', 9),
                var('P', 15), var('Q', 15)])
          end
        end

        context 'when job has scan execution policy variables_override' do
          context 'when the policy action does not define custom variables' do
            before do
              # ScanExecutionPolicy::Config builds { allowed: true } with no exceptions
              # when the action has no custom variables
              stub_ci_job_definition(job, options:
                job.options.merge(policy: { name: 'Policy', variables_override: { allowed: true } })
              )
            end

            it 'allows user-defined variables including secret_project_variables to pass through' do
              expect(scoped_variables.to_hash).to include('L' => '12')
            end

            it 'returns all variables in normal order' do
              expect(scoped_variables.to_hash_variables).to eq(
                [var('A', 1), var('B', 1),
                  var('B', 2), var('C', 2),
                  var('C', 3), var('D', 3),
                  var('D', 4), var('E', 4),
                  var('E', 5), var('F', 5),
                  var('G', 7), var('H', 7),
                  var('H', 8), var('I', 8),
                  var('I', 9), var('J', 9),
                  var('J', 10), var('K', 10),
                  var('K', 11), var('L', 11),
                  var('L', 12), var('M', 12),
                  var('M', 13), var('N', 13),
                  var('N', 14), var('O', 14),
                  var('P', 15), var('Q', 15)])
            end
          end

          context 'when the policy action defines a variable that also exists in secret_project_variables' do
            before do
              # ScanExecutionPolicy::Config builds { allowed: true, exceptions: ['L'] }
              # when the action defines variables: { L: 'policy_value' }.
              # This protects 'L' from being overridden by user-defined variables.
              stub_ci_job_definition(job, options:
                job.options.merge(policy: { name: 'Policy', variables_override: { allowed: true, exceptions: ['L'] } })
              )
            end

            it 'removes the excepted variable from user-defined variables' do
              expect(scoped_variables.to_hash_variables).to eq(
                [var('A', 1), var('B', 1),
                  var('B', 2), var('C', 2),
                  var('C', 3), var('D', 3),
                  var('D', 4), var('E', 4),
                  var('E', 5), var('F', 5),
                  var('G', 7), var('H', 7),
                  var('H', 8), var('I', 8),
                  var('I', 9), var('J', 9),
                  var('J', 10), var('K', 10),
                  var('K', 11),
                  var('M', 12),
                  var('M', 13), var('N', 13),
                  var('N', 14), var('O', 14),
                  var('P', 15), var('Q', 15)])
            end

            it 'prevents secret_project_variables from overriding the policy-defined variable' do
              expect(scoped_variables.to_hash).not_to include('L')
            end
          end
        end
      end
    end
  end

  describe '#scoped_variables_for_pipeline_seed' do
    let(:environment_name) { job.expanded_environment_name }
    let(:kubernetes_namespace) { job.expanded_kubernetes_namespace }
    let(:dependencies) { true }
    let(:extra_attributes) { {} }

    let(:job_attr) do
      {
        name: job.name,
        stage: job.stage_name,
        yaml_variables: job.yaml_variables,
        options: job.options,
        **extra_attributes
      }
    end

    subject(:scoped_variables_for_pipeline_seed) do
      builder.scoped_variables_for_pipeline_seed(
        job_attr,
        environment: environment_name,
        kubernetes_namespace: kubernetes_namespace,
        user: job.user,
        trigger: nil
      )
    end

    it { is_expected.to be_instance_of(Gitlab::Ci::Variables::Collection) }

    describe 'variables ordering' do
      before do
        pipeline_variables_builder = instance_double(
          ::Gitlab::Ci::Variables::Builder::Pipeline,
          predefined_variables: [var('C', 3), var('D', 3)]
        )
        allow(builder).to receive(:predefined_variables_from_job_attr) { [var('A', 1), var('B', 1)] }
        allow(pipeline.project).to receive(:predefined_variables) { [var('B', 2), var('C', 2)] }
        allow(builder).to receive(:pipeline_variables_builder) { pipeline_variables_builder }
        allow(pipeline).to receive(:predefined_variables) { [var('C', 3), var('D', 3)] }
        allow(builder).to receive(:kubernetes_variables) { [var('E', 5), var('F', 5)] }
        allow(job).to receive(:yaml_variables) { [var('G', 7), var('H', 7)] }
        allow(builder).to receive(:user_variables) { [var('H', 8), var('I', 8)] }
        allow(builder).to receive(:secret_instance_variables) { [var('J', 10), var('K', 10)] }
        allow(builder).to receive(:secret_group_variables) { [var('K', 11), var('L', 11)] }
        allow(builder).to receive(:secret_project_variables) { [var('L', 12), var('M', 12)] }
        allow(pipeline).to receive(:variables) { [var('M', 13), var('N', 13)] }
        allow(pipeline).to receive(:pipeline_schedule) do
          instance_double(::Ci::PipelineSchedule, job_variables: [var('N', 14), var('O', 14)])
        end
        allow(builder).to receive(:release_variables) { [var('P', 15), var('Q', 15)] }
      end

      it 'returns variables in order depending on resource hierarchy' do
        expect(scoped_variables_for_pipeline_seed.to_hash_variables).to eq(
          [var('A', 1), var('B', 1),
            var('B', 2), var('C', 2),
            var('C', 3), var('D', 3),
            var('E', 5), var('F', 5),
            var('G', 7), var('H', 7),
            var('H', 8), var('I', 8),
            var('J', 10), var('K', 10),
            var('K', 11), var('L', 11),
            var('L', 12), var('M', 12),
            var('M', 13), var('N', 13),
            var('N', 14), var('O', 14),
            var('P', 15), var('Q', 15)])
      end

      it 'overrides duplicate keys depending on resource hierarchy' do
        expect(scoped_variables_for_pipeline_seed.to_hash).to match(
          'A' => '1', 'B' => '2',
          'C' => '3', 'D' => '3',
          'E' => '5', 'F' => '5',
          'G' => '7', 'H' => '8',
          'I' => '8', 'J' => '10',
          'K' => '11', 'L' => '12',
          'M' => '13', 'N' => '14',
          'O' => '14', 'P' => '15',
          'Q' => '15')
      end

      context 'when using legacy SEP variables builder' do
        let(:builder) { described_class.new(pipeline) }

        before do
          scan_execution_policies_variables_builder = instance_double(
            ::EE::Gitlab::Ci::Variables::Builder::ScanExecutionPolicies,
            variables: [var('Q', 16), var('R', 16)]
          )
          allow(builder).to receive(:scan_execution_policies_variables_builder) do
            scan_execution_policies_variables_builder
          end
        end

        context 'when job does not have policy metadata' do
          it 'appends old SEP builder variables at the end of the chain' do
            expect(scoped_variables_for_pipeline_seed.to_hash_variables).to eq(
              [var('A', 1), var('B', 1),
                var('B', 2), var('C', 2),
                var('C', 3), var('D', 3),
                var('E', 5), var('F', 5),
                var('G', 7), var('H', 7),
                var('H', 8), var('I', 8),
                var('J', 10), var('K', 10),
                var('K', 11), var('L', 11),
                var('L', 12), var('M', 12),
                var('M', 13), var('N', 13),
                var('N', 14), var('O', 14),
                var('P', 15), var('Q', 15),
                var('Q', 16), var('R', 16)])
          end

          it 'overrides duplicate keys with old SEP builder variables' do
            expect(scoped_variables_for_pipeline_seed.to_hash).to match(
              'A' => '1', 'B' => '2',
              'C' => '3', 'D' => '3',
              'E' => '5', 'F' => '5',
              'G' => '7', 'H' => '8',
              'I' => '8', 'J' => '10',
              'K' => '11', 'L' => '12',
              'M' => '13', 'N' => '14',
              'O' => '14', 'P' => '15',
              'Q' => '16', 'R' => '16')
          end
        end

        context 'when job has policy metadata but no variables_override (FF disabled)' do
          before do
            stub_ci_job_definition(job, options: job.options.merge(policy: { name: 'Policy' }))
          end

          it 'still appends old SEP builder variables' do
            expect(scoped_variables_for_pipeline_seed.to_hash_variables).to eq(
              [var('A', 1), var('B', 1),
                var('B', 2), var('C', 2),
                var('C', 3), var('D', 3),
                var('E', 5), var('F', 5),
                var('G', 7), var('H', 7),
                var('H', 8), var('I', 8),
                var('J', 10), var('K', 10),
                var('K', 11), var('L', 11),
                var('L', 12), var('M', 12),
                var('M', 13), var('N', 13),
                var('N', 14), var('O', 14),
                var('P', 15), var('Q', 15),
                var('Q', 16), var('R', 16)])
          end

          it 'overrides duplicate keys with old SEP builder variables' do
            expect(scoped_variables_for_pipeline_seed.to_hash).to match(
              'A' => '1', 'B' => '2',
              'C' => '3', 'D' => '3',
              'E' => '5', 'F' => '5',
              'G' => '7', 'H' => '8',
              'I' => '8', 'J' => '10',
              'K' => '11', 'L' => '12',
              'M' => '13', 'N' => '14',
              'O' => '14', 'P' => '15',
              'Q' => '16', 'R' => '16')
          end
        end
      end

      context 'when job has variables_override option set to disallow user-defined variables' do
        before do
          stub_ci_job_definition(job, options:
            job.options.merge(policy: { name: 'Policy', variables_override: { allowed: false } })
          )
        end

        it 'returns variables without user-defined variables' do
          expect(scoped_variables_for_pipeline_seed.to_hash_variables).to eq(
            [var('A', 1), var('B', 1),
              var('B', 2), var('C', 2),
              var('C', 3), var('D', 3),
              var('E', 5), var('F', 5),
              var('G', 7), var('H', 7),
              var('H', 8), var('I', 8),
              var('P', 15), var('Q', 15)])
        end
      end

      context 'when job has scan execution policy variables_override' do
        context 'when the policy action does not define custom variables' do
          before do
            stub_ci_job_definition(job, options:
              job.options.merge(policy: { name: 'Policy', variables_override: { allowed: true } })
            )
          end

          it 'allows user-defined variables including secret_project_variables to pass through' do
            expect(scoped_variables_for_pipeline_seed.to_hash).to include('L' => '12')
          end

          it 'returns all variables in normal order' do
            expect(scoped_variables_for_pipeline_seed.to_hash_variables).to eq(
              [var('A', 1), var('B', 1),
                var('B', 2), var('C', 2),
                var('C', 3), var('D', 3),
                var('E', 5), var('F', 5),
                var('G', 7), var('H', 7),
                var('H', 8), var('I', 8),
                var('J', 10), var('K', 10),
                var('K', 11), var('L', 11),
                var('L', 12), var('M', 12),
                var('M', 13), var('N', 13),
                var('N', 14), var('O', 14),
                var('P', 15), var('Q', 15)])
          end
        end

        context 'when the policy action defines a variable that also exists in secret_project_variables' do
          before do
            stub_ci_job_definition(job, options:
              job.options.merge(policy: { name: 'Policy', variables_override: { allowed: true, exceptions: ['L'] } })
            )
          end

          it 'removes the excepted variable from user-defined variables' do
            expect(scoped_variables_for_pipeline_seed.to_hash_variables).to eq(
              [var('A', 1), var('B', 1),
                var('B', 2), var('C', 2),
                var('C', 3), var('D', 3),
                var('E', 5), var('F', 5),
                var('G', 7), var('H', 7),
                var('H', 8), var('I', 8),
                var('J', 10), var('K', 10),
                var('K', 11),
                var('M', 12),
                var('M', 13), var('N', 13),
                var('N', 14), var('O', 14),
                var('P', 15), var('Q', 15)])
          end

          it 'prevents secret_project_variables from overriding the policy-defined variable' do
            expect(scoped_variables_for_pipeline_seed.to_hash).not_to include('L')
          end
        end
      end
    end
  end

  describe '#protected_ref?', :clean_gitlab_redis_shared_state do
    let(:test_project) { create(:project, :repository) }
    let(:protected_branch) { create(:protected_branch, project: test_project, name: 'main') }

    let(:pipeline_source) { :push }
    let(:test_pipeline) { create(:ci_pipeline, project: test_project, ref: 'main', source: pipeline_source) }
    let(:test_builder) { described_class.new(test_pipeline) }

    before do
      protected_branch
    end

    subject(:protected_ref?) { test_builder.send(:protected_ref?) }

    context 'when pipeline is on a protected branch' do
      it 'returns true for regular pipelines' do
        expect(protected_ref?).to be true
      end

      context 'when pipeline is an on-demand DAST scan' do
        let(:pipeline_source) { :ondemand_dast_scan }

        it 'returns false to prevent protected variable exposure' do
          expect(protected_ref?).to be false
        end
      end
    end

    context 'when pipeline is not on a protected branch' do
      let(:test_pipeline) do
        create(:ci_pipeline, project: test_project, ref: 'feature-branch', source: pipeline_source)
      end

      it 'returns false for regular pipelines' do
        expect(protected_ref?).to be false
      end

      context 'when pipeline is an on-demand DAST scan' do
        let(:pipeline_source) { :ondemand_dast_scan }

        it 'returns false' do
          expect(protected_ref?).to be false
        end
      end
    end
  end

  def var(name, value)
    { key: name, value: value.to_s, public: true, masked: false, raw: false, file: false }
  end
end
