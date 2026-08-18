# frozen_string_literal: true

require 'spec_helper'

RSpec.shared_examples_for 'pipeline auditor' do
  let_it_be(:project, freeze: false) { build(:project) }

  describe '#audit' do
    subject(:audit) { described_class.new(pipeline: pipeline).audit }

    shared_examples 'does not call Gitlab::Audit::Auditor' do
      specify do
        expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

        audit
      end
    end

    context 'when pipeline is nil' do
      let_it_be(:pipeline) { nil }

      it_behaves_like 'does not call Gitlab::Audit::Auditor'
    end

    context 'when the pipeline is present' do
      let_it_be(:user, freeze: false) { build(:user) }
      let_it_be(:pipeline, freeze: false) { build(:ci_pipeline, project: project, user: user) }

      context 'when there is no security_orchestration_policy_configuration assigned to project' do
        it_behaves_like 'does not call Gitlab::Audit::Auditor'
      end

      context 'when there is a security_orchestration_policy_configuration assigned to project' do
        let_it_be(:security_policy_management_project) { build(:project) }
        let_it_be(:security_orchestration_policy_configuration) do
          build(:security_orchestration_policy_configuration, project: project,
            security_policy_management_project: security_policy_management_project)
        end

        let_it_be(:all_policies) { [security_orchestration_policy_configuration] }

        before do
          allow(project).to receive(:all_security_orchestration_policy_configurations).and_return(
            all_policies)

          allow(security_orchestration_policy_configuration).to receive(:active_scan_execution_policy_names).with(
            merge_request&.target_branch_ref, project).and_return(active_scan_execution_policy_names)

          allow(security_orchestration_policy_configuration).to receive(:active_pipeline_execution_policy_names)
            .and_return(active_pipeline_execution_policy_names)
        end

        context 'when there are no active policies' do
          let(:active_scan_execution_policy_names) { [] }
          let(:active_pipeline_execution_policy_names) { [] }
          let(:merge_request) { nil }

          it_behaves_like 'does not call Gitlab::Audit::Auditor'
        end

        context 'when there are active policies' do
          shared_examples_for 'calls Gitlab::Audit::Auditor.audit with the expected context' do
            specify do
              expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
                hash_including(
                  {
                    name: event_name,
                    author: user,
                    scope: security_policy_management_project,
                    target: pipeline,
                    target_details: pipeline.id.to_s,
                    message: event_message,
                    additional_details: additional_details
                  }
                )
              )

              audit
            end
          end

          shared_examples_for 'when the merge_request is present' do
            context 'when the merge_request is present' do
              let_it_be(:merge_request) do
                build(:merge_request, id: 1, iid: 1, source_project: project, target_project: project)
              end

              let(:additional_details) do
                {
                  commit_sha: pipeline.sha,
                  merge_request_title: merge_request.title,
                  merge_request_id: merge_request.id,
                  merge_request_iid: merge_request.iid,
                  source_branch: merge_request.source_branch,
                  target_branch: merge_request.target_branch,
                  project_id: project.id,
                  project_name: project.name,
                  project_full_path: project.full_path,
                  skipped_policies: skipped_policies_details
                }
              end

              before do
                pipeline.merge_request = merge_request

                merge_requests_relation = instance_double(ActiveRecord::Relation)

                allow(pipeline).to receive(:all_merge_requests).and_return(merge_requests_relation)
                allow(merge_requests_relation).to receive(:first).and_return(merge_request)
              end

              it_behaves_like 'calls Gitlab::Audit::Auditor.audit with the expected context'
            end
          end

          context 'when there are active scan_execution_policies policies' do
            let(:skipped_policy_name) { 'Skipped sep policy' }
            let(:skipped_policies_details) { [{ name: skipped_policy_name, policy_type: 'scan_execution_policy' }] }

            let(:active_scan_execution_policy_names) { [skipped_policy_name] }
            let(:active_pipeline_execution_policy_names) { [] }

            it_behaves_like 'when the merge_request is present'
          end

          context 'when there are active pipeline_execution_policies policies' do
            let(:skipped_policy_name) { 'Skipped pep policy' }
            let(:skipped_policies_details) { [{ name: skipped_policy_name, policy_type: 'pipeline_execution_policy' }] }

            let(:active_scan_execution_policy_names) { [] }
            let(:active_pipeline_execution_policy_names) { [skipped_policy_name] }

            it_behaves_like 'when the merge_request is present'

            context 'when merge_request is nil' do
              let(:merge_request) { nil }
              let(:additional_details) do
                {
                  commit_sha: pipeline.sha,
                  project_id: project.id,
                  project_name: project.name,
                  project_full_path: project.full_path,
                  skipped_policies: skipped_policies_details
                }
              end

              before do
                pipeline.merge_request = merge_request
              end

              it_behaves_like 'calls Gitlab::Audit::Auditor.audit with the expected context'
            end
          end

          context 'when there are active scan_execution and pipeline_execution policies' do
            let(:skipped_sep_policy_name) { 'Skipped sep policy' }
            let(:skipped_pep_policy_name) { 'Skipped pep policy' }
            let(:skipped_policies_details) do
              [{ name: skipped_sep_policy_name, policy_type: 'scan_execution_policy' },
                { name: skipped_pep_policy_name,
                  policy_type: 'pipeline_execution_policy' }]
            end

            let(:active_scan_execution_policy_names) { [skipped_sep_policy_name] }
            let(:active_pipeline_execution_policy_names) { [skipped_pep_policy_name] }

            it_behaves_like 'when the merge_request is present'

            context 'when there are inherited security_orchestration_policy_configurations' do
              let_it_be(:inherited_security_policy_management_project) { build(:project) }
              let(:inherited_skipped_sep_policy_name) { 'Inherited skipped sep policy' }
              let(:inherited_skipped_pep_policy_name) { 'Inherited skipped pep policy' }
              let(:inherited_active_scan_execution_policy_names) { [inherited_skipped_sep_policy_name] }
              let(:inherited_active_pipeline_execution_policy_names) { [inherited_skipped_pep_policy_name] }
              let(:inherited_skipped_policies_details) do
                [{ name: inherited_skipped_sep_policy_name, policy_type: 'scan_execution_policy' },
                  { name: inherited_skipped_pep_policy_name,
                    policy_type: 'pipeline_execution_policy' }]
              end

              let_it_be(:parent_group) { build(:group) }
              let_it_be(:inherited_security_orchestration_policy_configuration) do
                build(:security_orchestration_policy_configuration, namespace: parent_group,
                  security_policy_management_project: inherited_security_policy_management_project)
              end

              let_it_be(:all_policies) do
                [security_orchestration_policy_configuration, inherited_security_orchestration_policy_configuration]
              end

              before do
                allow(inherited_security_orchestration_policy_configuration)
                  .to receive(:active_scan_execution_policy_names).with(
                    merge_request&.target_branch_ref, project).and_return(inherited_active_scan_execution_policy_names)

                allow(inherited_security_orchestration_policy_configuration)
                  .to receive(:active_pipeline_execution_policy_names)
                  .and_return(inherited_active_pipeline_execution_policy_names)
              end

              context 'when the merge_request is present' do
                let_it_be(:merge_request) do
                  build(:merge_request, id: 1, iid: 1, source_project: project, target_project: project)
                end

                let(:additional_details) do
                  {
                    commit_sha: pipeline.sha,
                    merge_request_title: merge_request.title,
                    merge_request_id: merge_request.id,
                    merge_request_iid: merge_request.iid,
                    source_branch: merge_request.source_branch,
                    target_branch: merge_request.target_branch,
                    project_id: project.id,
                    project_name: project.name,
                    project_full_path: project.full_path
                  }
                end

                before do
                  pipeline.merge_request = merge_request

                  merge_requests_relation = instance_double(ActiveRecord::Relation)

                  allow(pipeline).to receive(:all_merge_requests).and_return(merge_requests_relation)
                  allow(merge_requests_relation).to receive(:first).and_return(merge_request)
                end

                it 'calls Gitlab::Audit::Auditor.audit for each policy configuration with the expected context' do
                  security_policy_projects = [security_policy_management_project,
                    inherited_security_policy_management_project]
                  additional_details_including_policies = [
                    additional_details.merge({ skipped_policies: skipped_policies_details }),
                    additional_details.merge({ skipped_policies: inherited_skipped_policies_details })
                  ]

                  all_policies.size.times do |index|
                    expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
                      hash_including(
                        {
                          name: event_name,
                          author: user,
                          scope: security_policy_projects[index],
                          target: pipeline,
                          target_details: pipeline.id.to_s,
                          message: event_message,
                          additional_details: additional_details_including_policies[index]
                        }
                      )
                    )
                  end

                  audit
                end
              end
            end
          end
        end
      end
    end
  end
end
