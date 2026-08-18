# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'projects/settings/merge_requests/show', feature_category: :code_review_workflow do
  let(:project) { build_stubbed(:project) }
  let(:user) { build_stubbed(:admin) }

  before do
    assign(:project, project)

    allow(view).to receive(:current_user).and_return(user)
  end

  describe 'Duo Code Review' do
    context 'when auto_duo_code_review_settings are available' do
      before do
        allow(project).to receive_messages(duo_features_enabled: true, auto_duo_code_review_settings_available?: true)
      end

      it 'displays the setting header' do
        render

        expect(rendered).to have_content 'GitLab Duo Code Review'
      end

      it 'displays the setting form', :aggregate_failures do
        render

        expect(rendered).to have_css('input[id=project_project_setting_attributes_auto_duo_code_review_enabled]')
      end
    end

    context 'when duo_features_enabled but foundational flows not configured' do
      before do
        allow(project).to receive_messages(duo_features_enabled: true, auto_duo_code_review_settings_available?: false)
      end

      it 'displays the setting header' do
        render

        expect(rendered).to have_content 'GitLab Duo Code Review'
      end

      it 'displays the checkbox as disabled with a help link', :aggregate_failures do
        render

        input_selector = 'input[id=project_project_setting_attributes_auto_duo_code_review_enabled][disabled]'
        expect(rendered).to have_css(input_selector)
        expect(rendered).to have_content 'Requires the Code Review foundational flow to be enabled'
      end
    end

    context 'when auto_duo_code_review_settings are not available' do
      before do
        allow(project).to receive(:duo_features_enabled).and_return(false)
      end

      it 'does not display the setting' do
        render
        expect(rendered).not_to have_content 'GitLab Duo Code Review'
      end
    end
  end

  describe 'merge request title regex description' do
    context 'when merge_request_title_regex_check license is available' do
      before do
        stub_licensed_features(merge_request_title_regex_check: true)
      end

      it 'renders the toggle checkbox within the merge checks section' do
        render

        expect(rendered).to have_content('Title must match required pattern')
      end

      it 'renders hidden fallback fields for clearing values on unchecked save' do
        render

        expect(rendered).to have_css(
          'input#merge_request_title_regex_hidden[type="hidden"][value=""]', visible: :hidden
        )
        expect(rendered).to have_css(
          'input#merge_request_title_regex_description_hidden[type="hidden"][value=""]', visible: :hidden
        )
      end

      context 'when no title regex is configured' do
        it 'renders the checkbox unchecked with aria-expanded false' do
          render

          expect(rendered).to have_css(
            '[data-testid="title-regex-toggle"]' \
              ':not([checked])' \
              '[aria-expanded="false"]' \
              '[aria-controls="title-regex-fields"]'
          )
        end

        it 'renders the fields container hidden with an id' do
          render

          expect(rendered).to have_css('#title-regex-fields[data-testid="title-regex-fields"].gl-hidden')
        end

        it 'displays a placeholder if none is set' do
          render

          expect(rendered).to have_field(
            'project[merge_request_title_regex_description]',
            placeholder: '[Feature] Add login'
          )
        end
      end

      context 'when a title regex is configured' do
        before do
          project.merge_request_title_regex = '\d+-.*'
          project.merge_request_title_regex_description = 'Number prefix required'
        end

        it 'renders the checkbox checked with aria-expanded true' do
          render

          expect(rendered).to have_css(
            '[data-testid="title-regex-toggle"][checked][aria-expanded="true"][aria-controls="title-regex-fields"]'
          )
        end

        it 'renders the fields container visible with an id' do
          render

          expect(rendered).to have_css('#title-regex-fields[data-testid="title-regex-fields"]')
          expect(rendered).not_to have_css('[data-testid="title-regex-fields"].gl-hidden')
        end

        it 'displays the user entered value' do
          render

          expect(rendered).to have_field(
            'project[merge_request_title_regex_description]', with: 'Number prefix required'
          )
        end
      end
    end

    context 'when merge_request_title_regex_check license is not available' do
      before do
        stub_licensed_features(merge_request_title_regex_check: false)
      end

      it 'does not display the field' do
        render

        expect(rendered).not_to have_field('project[merge_request_title_regex_description]')
      end
    end
  end
end
