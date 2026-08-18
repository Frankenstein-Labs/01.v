# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Duo::CodeReview, feature_category: :duo_code_review do
  let_it_be(:group) { build_stubbed(:group) }
  let_it_be(:project) { build_stubbed(:project, group: group) }
  let_it_be(:merge_request) { build_stubbed(:merge_request, source_project: project) }
  let_it_be(:user) { build_stubbed(:user, developer_of: project) }

  describe '.enabled?' do
    let(:active_mode) { instance_double(Gitlab::Duo::CodeReview::Modes::Base, enabled?: double) }

    shared_examples 'delegates to ModeResolver.enabled?' do
      it 'delegates to ModeResolver.enabled?' do
        stub_active_mode_with(active_mode)

        expect(active_mode).to receive(:enabled?)

        described_class.enabled?(user: user, container: container)
      end
    end

    context 'when container is a group' do
      let(:container) { group }

      include_examples 'delegates to ModeResolver.enabled?'
    end

    context 'when container is a project' do
      let(:container) { project }

      include_examples 'delegates to ModeResolver.enabled?'
    end
  end

  describe '.mode' do
    let(:active_mode) { instance_double(Gitlab::Duo::CodeReview::Modes::Base, mode: double) }

    shared_examples 'delegates to ModeResolver.mode' do
      it 'delegates to ModeResolver.mode' do
        stub_active_mode_with(active_mode)

        expect(active_mode).to receive(:mode)

        described_class.mode(user: user, container: container)
      end
    end

    context 'when container is a group' do
      let(:container) { group }

      include_examples 'delegates to ModeResolver.mode'
    end

    context 'when container is a project' do
      let(:container) { project }

      include_examples 'delegates to ModeResolver.mode'
    end
  end

  describe '.dap?' do
    subject(:dap) { described_class.dap?(user: user, container: project) }

    before do
      stub_active_mode_with(active_mode)
    end

    context 'when active mode is dap' do
      let(:active_mode) { instance_double(Gitlab::Duo::CodeReview::Modes::Dap, mode: :dap) }

      it { is_expected.to be(true) }
    end

    context 'when active mode is classic' do
      let(:active_mode) { instance_double(Gitlab::Duo::CodeReview::Modes::Classic, mode: :classic) }

      it { is_expected.to be(false) }
    end

    context 'when active mode is disabled' do
      let(:active_mode) { instance_double(Gitlab::Duo::CodeReview::Modes::Disabled, mode: :disabled) }

      it { is_expected.to be(false) }
    end
  end

  private

  def stub_active_mode_with(active_mode)
    allow(Gitlab::Duo::CodeReview::ModeResolver)
      .to receive(:new)
      .and_return(active_mode)
  end
end
