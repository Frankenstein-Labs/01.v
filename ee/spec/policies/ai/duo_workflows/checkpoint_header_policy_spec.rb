# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::CheckpointHeaderPolicy, feature_category: :duo_agent_platform do
  subject(:policy) { described_class.new(current_user, checkpoint_header) }

  let_it_be(:group) { create(:group) }
  let_it_be_with_reload(:project) { create(:project, group: group) }
  let_it_be_with_reload(:workflow) { create(:duo_workflows_workflow, project: project) }
  let_it_be_with_reload(:checkpoint_header) do
    create(:duo_workflows_checkpoint_header, project: project, workflow: workflow)
  end

  let_it_be(:guest) { create(:user, guest_of: checkpoint_header.project) }
  let_it_be(:developer) { create(:user, developer_of: checkpoint_header.project) }
  let(:current_user) { guest }

  describe "read_duo_workflow_event" do
    context "when duo workflow is not available" do
      before do
        allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(false)
      end

      it { expect_disallowed(:read_duo_workflow_event) }
    end

    context "when duo workflow is available" do
      before do
        allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(true)
      end

      context "when user is guest" do
        it { expect_disallowed(:read_duo_workflow_event) }
      end

      context "when user is a developer" do
        let(:current_user) { developer }

        context "when user is not workflow owner" do
          it { expect_disallowed(:read_duo_workflow_event) }
        end

        context "when user is workflow owner" do
          before do
            checkpoint_header.workflow.update!(user: current_user)
          end

          context "when duo_features_enabled settings is turned off" do
            before do
              project.project_setting.update!(duo_features_enabled: false)
            end

            it { expect_disallowed(:read_duo_workflow) }
            it { expect_disallowed(:update_duo_workflow) }
          end

          context "when duo_features_enabled settings is turned on" do
            before do
              project.project_setting.update!(duo_features_enabled: true)
            end

            context "when user is not allowed to use duo_agent_platfrom" do
              before do
                allow(current_user).to receive(:allowed_to_use?).and_return(false)
              end

              it { expect_disallowed(:read_duo_workflow) }
              it { expect_disallowed(:update_duo_workflow) }
            end

            context "when user is allowed to use duo_agent_platfrom" do
              before do
                allow(current_user).to receive(:allowed_to_use?).and_return(true)
              end

              it { expect_allowed(:read_duo_workflow_event) }
            end
          end
        end
      end
    end
  end
end
