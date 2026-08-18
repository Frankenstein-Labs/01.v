# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'shared/mirror_update_button' do
  let(:partial) { 'shared/mirror_update_button' }

  let_it_be(:project) { create(:project, :mirror) }

  let(:import_state) { project.import_state }

  let(:owner) { project.first_owner }
  let(:developer) { create(:user, developer_of: project.team) }
  let(:reporter) { create(:user, reporter_of: project.team) }

  let(:update_link) { update_now_project_mirror_path(project) }
  let(:have_update_button) { have_link('Update now', href: update_link) }

  before do
    @project = project
  end

  subject { rendered }

  context 'mirror update can be triggered' do
    context 'user is owner' do
      it 'renders a working update button' do
        render partial, current_user: owner

        is_expected.to have_update_button
      end
    end

    context 'user is developer' do
      it 'renders a disabled update button' do
        render partial, current_user: developer

        is_expected.to have_text('Update now')
        is_expected.not_to have_update_button
      end
    end

    context 'user is anonymous' do
      it 'renders nothing' do
        render partial, current_user: nil

        is_expected.to eq('')
      end
    end
  end

  context 'mirror update due' do
    it 'renders a disabled update button' do
      expect(import_state).to receive(:mirror_update_due?).and_return(true)
      allow(import_state).to receive(:last_successful_update_at) { Time.now }

      render partial, current_user: owner

      is_expected.to have_text('scheduled…')
      is_expected.not_to have_update_button
    end
  end

  context 'mirror is currently updating' do
    it 'renders a disabled update button' do
      expect(import_state).to receive(:updating_mirror?).and_return(true)

      render partial, current_user: owner

      is_expected.to have_text('Updating…')
      is_expected.not_to have_update_button
    end
  end

  context 'project is not a mirror' do
    let(:project) { create(:project) }

    it 'renders nothing' do
      is_expected.to eq('')
    end
  end
end
