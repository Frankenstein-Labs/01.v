# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Duo::Administration::VerifySetup, feature_category: :ai_abstraction_layer do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, namespace: group) }

  let(:task) { described_class.new(project.full_path) }

  describe '#execute' do
    def run_execute
      task.execute
    rescue SystemExit
      nil
    end

    context 'when the project path is blank' do
      let(:task) { described_class.new('') }

      it 'exits' do
        expect { task.execute }.to raise_error(SystemExit)
      end

      it 'prints usage instructions' do
        expect { run_execute }.to output(
          /Usage: bundle exec rake "gitlab:support:duo_code_review_debug\[PROJECT_PATH\]"/
        ).to_stdout
      end
    end

    context 'when the project does not exist' do
      let(:task) { described_class.new('does-not-exist/does-not-exist') }

      it 'exits' do
        expect { task.execute }.to raise_error(SystemExit)
      end

      it 'prints a not found message' do
        expect { run_execute }.to output(
          %r{Project "does-not-exist/does-not-exist" does not exist\. Check the path and try again\.}
        ).to_stdout
      end
    end

    context 'when the project exists' do
      it 'completes without raising' do
        expect { run_execute }.not_to raise_error
      end

      it 'prints the project section' do
        expect { run_execute }.to output(/4\. Project: #{Regexp.escape(project.full_path)}/).to_stdout
      end

      it 'prints the Duo Code Review section' do
        expect { run_execute }.to output(/8\. Duo Code Review for Project: #{Regexp.escape(project.full_path)}/)
          .to_stdout
      end
    end
  end

  describe '#check_duo_code_review_availability (private)', :aggregate_failures do
    def run_check
      task.send(:check_duo_code_review_availability)
    end

    let(:settings_available) { true }
    let(:dap_available) { true }
    let(:has_enterprise_addon) { true }
    let(:consent_given) { true }

    before do
      allow(::Project).to receive(:find_by_full_path).with(project.full_path).and_return(project)
      allow(project).to receive_messages(
        auto_duo_code_review_settings_available?: settings_available,
        duo_code_review_dap_available?: dap_available
      )
      allow(project.namespace).to receive(:has_active_add_on_purchase?)
        .with([:duo_enterprise]).and_return(has_enterprise_addon)
      allow(group).to receive(:consented_to?).with(:code_review_flow_dap_routing).and_return(consent_given)
    end

    context 'when a Duo Enterprise namespace has consented' do
      it 'reports DAP mode for Duo Enterprise seat holders' do
        expect { run_check }.to output(
          /Mode: DAP - Duo Enterprise seat holders are routed through Code Review Flow \(consent given\)/
        ).to_stdout
      end
    end

    context 'when consent has not been given' do
      let(:consent_given) { false }

      it 'reports Classic mode with a remediation hint' do
        expect { run_check }.to output(
          /Mode:\ Classic\ for\ Duo\ Enterprise\ seat\ holders.*
            Reason:\ consent\ has\ not\ been\ given\ for\ this\ namespace\ yet.*
            group\ Owner\ must\ confirm\ Code\ Review\ Flow/mx
        ).to_stdout
      end
    end

    context 'when DAP is not available for the project' do
      let(:dap_available) { false }

      it 'reports Classic mode for Duo Enterprise, independent of consent' do
        expect { run_check }.to output(/Mode: Classic - non-agentic Duo Enterprise code review/).to_stdout
      end
    end

    context 'when the namespace has no Duo Enterprise add-on' do
      let(:has_enterprise_addon) { false }

      it 'reports plain DAP mode, unaffected by consent' do
        expect { run_check }.to output(
          /Mode: DAP \(Duo Agent Platform\) - extended agentic code review/
        ).to_stdout
      end
    end

    context 'when Duo Code Review settings are not available at all' do
      let(:settings_available) { false }

      it 'reports Duo Code Review as unavailable' do
        expect { run_check }.to output(/Duo Code Review is NOT available for this project/).to_stdout
      end
    end
  end
end
