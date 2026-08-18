# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Admin manages runner cost factor', :js, feature_category: :fleet_visibility do
  include Spec::Support::Helpers::ModalHelpers

  let_it_be(:admin) { create(:admin) }

  before do
    sign_in(admin)
    enable_admin_mode!(admin)
  end

  shared_examples 'shows populated cost factor' do
    it 'shows cost factor fields' do
      expect(page).to have_field(_('Public projects compute cost factor'), with: '1')
      expect(page).to have_field(_('Private projects compute cost factor'), with: '1')
    end

    it 'submits correctly' do
      find('button:not([aria-disabled="true"])', text: _('Save changes')).click

      expect(page).to have_content(_('Changes saved.'))
    end
  end

  shared_examples 'does not show cost factor' do
    it 'does not show cost factor fields' do
      expect(page).not_to have_field(_('Public projects compute cost factor'))
      expect(page).not_to have_field(_('Private projects compute cost factor'))
    end

    it 'submits correctly' do
      find('button:not([aria-disabled="true"])', text: _('Save changes')).click

      expect(page).to have_content(_('Changes saved.'))
    end
  end

  describe 'cost factor' do
    let_it_be(:instance_runner) { create(:ci_runner, :instance) }
    let_it_be(:project_runner) { create(:ci_runner, :project, projects: [create(:project)]) }

    before do
      allow(Gitlab).to receive(:com?).and_return(dot_com)
      visit edit_admin_runner_path(runner)
    end

    context 'when Gitlab.com?' do
      let(:dot_com) { true }

      context 'when editing an instance runner' do
        let(:runner) { instance_runner }

        it_behaves_like 'shows populated cost factor'
      end

      context 'when editing a project runner' do
        let(:runner) { project_runner }

        it_behaves_like 'does not show cost factor'
      end
    end

    context 'when not Gitlab.com?' do
      let(:dot_com) { false }

      context 'when editing an instance runner' do
        let(:runner) { instance_runner }

        it_behaves_like 'does not show cost factor'
      end

      context 'when editing a project runner' do
        let(:runner) { project_runner }

        it_behaves_like 'does not show cost factor'
      end
    end
  end
end
