# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::EnablementCheckService, type: :service, feature_category: :duo_agent_platform do
  let_it_be(:group) { create(:group) }
  let_it_be_with_reload(:project) { create(:project, group: group) }
  let_it_be(:user) { create(:user) }

  describe '#execute' do
    subject(:result) { described_class.new(project: project, current_user: user).execute }

    it { is_expected.to be_nil }

    context "when user has developer access" do
      before_all do
        project.add_developer(user)
      end

      it { is_expected.not_to be_nil }

      it 'includes remote_flows_enabled in the response' do
        expect(result).to have_key(:remote_flows_enabled)
      end

      it 'includes foundational_flows_enabled in the response' do
        expect(result).to have_key(:foundational_flows_enabled)
      end

      context 'when duo_workflow licensed feature is available' do
        before do
          allow(::Gitlab::Llm::StageCheck).to receive(:available?).and_return(true)
          # rubocop:disable RSpec/AnyInstanceOf -- not the next instance
          allow_any_instance_of(User).to receive_messages(allowed_to_use?: true, allowed_to_use_for_resource?: true)
          # rubocop:enable RSpec/AnyInstanceOf
        end

        it "returns status and checks" do
          expect(result[:enabled]).to be(true)
          expect(result[:create_duo_workflow_for_ci_allowed]).to be(true)
          expect(success_checks(result[:checks]))
            .to contain_exactly(:developer_access, :duo_features_enabled, :feature_flag, :feature_available)
          expect(result[:remote_flows_enabled]).to eq(project.duo_remote_flows_enabled)
          expect(result[:foundational_flows_enabled]).to eq(project.duo_foundational_flows_enabled)
        end

        context 'when the user cannot create workflows for ci' do
          before do
            stub_feature_flags(dap_instance_customizable_permissions: true)
            Ai::Setting.for_organization(project.organization).update!(minimum_access_level_execute_async: ::Gitlab::Access::MAINTAINER)
          end

          it 'returns correct values for permissions related fields' do
            expect(result[:enabled]).to be(true)
            expect(result[:create_duo_workflow_for_ci_allowed]).to be(false)
          end
        end
      end

      context 'when project has duo features disabled' do
        before do
          project.project_setting.update!(duo_features_enabled: false)
        end

        it "returns status and checks" do
          expect(result[:enabled]).to be(false)
          expect(result[:create_duo_workflow_for_ci_allowed]).to be(false)
          expect(success_checks(result[:checks])).to contain_exactly(:feature_flag)
          expect(result[:remote_flows_enabled]).to eq(project.duo_remote_flows_enabled)
          expect(result[:foundational_flows_enabled]).to eq(project.duo_foundational_flows_enabled)
        end
      end

      context 'when project has duo remote flows enabled' do
        before do
          allow(project).to receive(:duo_remote_flows_enabled).and_return(true)
        end

        it "returns remote_flows_enabled as true" do
          expect(result[:remote_flows_enabled]).to be(true)
        end
      end

      context 'when project has duo remote flows disabled' do
        before do
          allow(project).to receive(:duo_remote_flows_enabled).and_return(false)
        end

        it "returns remote_flows_enabled as false" do
          expect(result[:remote_flows_enabled]).to be(false)
        end
      end

      context 'when project has duo foundational flows enabled' do
        before do
          allow(project).to receive(:duo_foundational_flows_enabled).and_return(true)
        end

        it "returns foundational_flows_enabled as true" do
          expect(result[:foundational_flows_enabled]).to be(true)
        end
      end

      context 'when project has duo foundational flows disabled' do
        before do
          allow(project).to receive(:duo_foundational_flows_enabled).and_return(false)
        end

        it "returns foundational_flows_enabled as false" do
          expect(result[:foundational_flows_enabled]).to be(false)
        end
      end

      it 'includes enabled_foundational_flows in the response' do
        expect(result[:enabled_foundational_flows]).to eq(project.enabled_foundational_flow_references)
      end
    end

    context 'when user has guest access' do
      before_all do
        project.add_guest(user)
      end

      it "returns status and checks" do
        expect(result[:enabled]).to be(true)
        expect(result[:create_duo_workflow_for_ci_allowed]).to be(false)
        expect(success_checks(result[:checks])).to contain_exactly(:duo_features_enabled, :feature_flag)
        expect(result[:remote_flows_enabled]).to eq(project.duo_remote_flows_enabled)
        expect(result[:foundational_flows_enabled]).to eq(project.duo_foundational_flows_enabled)
      end
    end

    def success_checks(checks)
      checks.filter { |check| check[:value] }.pluck(:name)
    end
  end
end
