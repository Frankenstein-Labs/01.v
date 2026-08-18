# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::Settings::PackagesAndRegistriesController, feature_category: :package_registry do
  let_it_be(:project) { create(:project) }
  let(:user) { project.creator }

  describe 'GET #show' do
    subject(:show) { get project_settings_packages_and_registries_path(project) }

    before do
      sign_in(user)
    end

    context 'for create_container_registry_protection_immutable_tag_rule ability' do
      shared_examples 'pushing frontend ability' do
        it 'sets the frontend ability correctly' do
          show

          expect(response.body).to have_pushed_frontend_ability(
            createContainerRegistryProtectionImmutableTagRule: ability_allowed
          )
        end
      end

      before do
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?)
          .with(user, :create_container_registry_protection_immutable_tag_rule, project)
          .and_return(ability_allowed)
      end

      context 'when ability is allowed' do
        let(:ability_allowed) { true }

        it_behaves_like 'pushing frontend ability'
      end

      context 'when ability is not allowed' do
        let(:ability_allowed) { false }

        it_behaves_like 'pushing frontend ability'
      end
    end
  end
end
