# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Onboarding::GetStartedPresenter, :aggregate_failures, feature_category: :onboarding do
  let(:namespace) { build_stubbed(:group) }
  let(:project) { build_stubbed(:project, namespace: namespace) }
  let(:onboarding_progress) { build(:onboarding_progress, namespace: namespace) }
  let(:user) { build(:user) }
  let(:presenter) { described_class.new(user, project, onboarding_progress) }

  describe '#view_model' do
    let(:parsed_view_model) { Gitlab::Json.parse(view_model) }
    let(:sections) { parsed_view_model['sections'] }

    subject(:view_model) { presenter.view_model }

    it 'returns a JSON string with view_model' do
      expect(view_model).to be_a(String)
      expect(parsed_view_model).to include('sections', 'tutorialEndPath')
    end

    it 'includes all required sections' do
      expect(sections.size).to eq(4)

      titles = [
        s_('LearnGitLab|Set up your code'),
        s_('LearnGitLab|Configure a project'),
        s_('LearnGitLab|Plan and execute work together'),
        s_('LearnGitLab|Secure your deployment')
      ]
      expect(sections.pluck('title')).to eq(titles)
    end

    it 'has correct structure for all sections' do
      expect(sections).to all(include('title', 'description', 'actions'))

      structure = ->(section) do
        section['title'].is_a?(String) && [String, NilClass].include?(section['description'].class) &&
          section['actions'].is_a?(Array)
      end

      expect(sections).to all(satisfy(&structure))

      actions_structure = ->(action) do
        action['title'].is_a?(String) &&
          action['trackLabel'].is_a?(String) &&
          action['url'].is_a?(String)
      end

      expect(sections.flat_map { |section| section['actions'] }).to all(satisfy(&actions_structure))
      expect(sections.find { |section| section['trialActions'] }&.fetch('trialActions'))
        .to all(satisfy(&actions_structure))
    end

    context 'for project section' do
      let(:trial_actions) { section['trialActions'] }
      let(:actions) { section['actions'] }
      let(:invite_action) { actions.find { |action| action['urlType'] == 'invite' } }
      let(:trial_action) { find_action_by_label(actions, 'start_a_free_trial_of_gitlab_ultimate') }

      subject(:section) { sections.second }

      it 'has trialActions' do
        expect(trial_actions).to be_an(Array)
      end

      it 'includes the correct number of actions' do
        expect(actions.size).to eq(3)
      end

      context 'when invite is enabled' do
        before do
          allow(user).to receive(:can?)
          allow(user).to receive(:can?).with(:invite_member, project).and_return(true)
        end

        it 'marks invite action as enabled' do
          expect(invite_action['enabled']).to be true
        end
      end

      context 'when invite is disabled' do
        it 'marks invite action as disabled' do
          expect(invite_action['enabled']).to be false
        end
      end

      context 'when user can admin namespace' do
        before do
          allow(user).to receive(:can?)
          allow(user).to receive(:can?).with(:admin_namespace, namespace).and_return(true)
        end

        it 'marks trial action as enabled' do
          expect(trial_action['enabled']).to be true
        end
      end

      context 'when user cannot admin namespace' do
        it 'marks trial action as disabled' do
          expect(trial_action['enabled']).to be false
        end
      end
    end

    context 'for plan section' do
      subject(:actions) { sections.third['actions'] }

      it 'includes the correct number of actions' do
        expect(actions.size).to eq(2)
      end
    end

    context 'for secure deployment section' do
      let(:actions) { section['actions'] }
      let(:scan_action) { find_action_by_label(actions, 'scan_dependencies_for_vulnerabilities') }
      let(:dast_action) { find_action_by_label(actions, 'analyze_your_application_for_vulnerabilities_with_dast') }

      subject(:section) { sections.fourth }

      it 'includes the correct number of actions' do
        expect(actions.size).to eq(3)
      end

      context 'when user can read_project_security_dashboard' do
        before do
          allow(user).to receive(:can?)
          allow(user).to receive(:can?).with(:read_project_security_dashboard, project).and_return(true)
        end

        it 'marks scan action as enabled' do
          expect(scan_action['enabled']).to be true
        end

        it 'marks dast action as enabled' do
          expect(dast_action['enabled']).to be true
        end
      end

      context 'when user cannot read_project_security_dashboard' do
        it 'marks scan action as disabled' do
          expect(scan_action['enabled']).to be false
        end

        it 'marks dast action as disabled' do
          expect(dast_action['enabled']).to be false
        end
      end
    end

    def find_action_by_label(actions, label)
      actions.find { |a| a['trackLabel'] == label }
    end
  end

  describe '#provide' do
    let(:parsed_provide) { Gitlab::Json.parse(provide) }

    subject(:provide) { presenter.provide }

    it 'returns a JSON string with provide' do
      keys = %w[projectName projectPath sshUrl httpUrl defaultBranch canPushCode canPushToBranch uploadPath sshKeyPath]

      expect(provide).to be_a(String)
      expect(parsed_provide).to include(*keys)
    end

    it 'has all the expected values' do
      expect(parsed_provide['canPushCode']).to be(false)
      expect(parsed_provide['canPushToBranch']).to be(false)
      expect(parsed_provide['uploadPath']).to include(project.full_path)
      expect(parsed_provide['sshUrl']).to include(project.ssh_url_to_repo)
      expect(parsed_provide['httpUrl']).to include(project.http_url_to_repo)
      expect(parsed_provide['defaultBranch']).to include(project.default_branch_or_main)
      expect(parsed_provide['projectName']).to eq(project.name)
      expect(parsed_provide['projectPath']).to eq(project.full_path)
      expect(parsed_provide['uploadPath']).to include(project.default_branch_or_main)
      expect(parsed_provide['uploadPath']).to include(project.full_path)
      expect(parsed_provide['sshKeyPath']).to include(user_settings_ssh_keys_path)
    end

    context 'for when user can push code' do
      it 'returns true for canPushCode' do
        allow(user).to receive(:can?)
        allow(user).to receive(:can?).with(:push_code, project).and_return(true)

        expect(parsed_provide['canPushCode']).to be(true)
      end
    end

    context 'for when user can push to branch' do
      it 'returns true for canPushToBranch' do
        allow_next_instance_of(::Gitlab::UserAccess, user, container: project) do |instance|
          allow(instance).to receive(:can_push_to_branch?).and_return(true)
        end

        expect(parsed_provide['canPushToBranch']).to be(true)
      end
    end
  end
end
