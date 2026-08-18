# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Container Registry', :js, feature_category: :container_registry do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, developers: user) }

  before_all do
    create(:container_repository, name: 'my/image')
    create(:container_repository, name: '')
  end

  before do
    sign_in(user)

    stub_container_registry_info
    stub_container_registry_tags(repository: :any, tags: [])
    allow(ContainerRegistry::GitlabApiClient).to receive(:supports_gitlab_api?).and_return(true)
  end

  context 'when container registry config enabled' do
    before do
      stub_container_registry_config(enabled: true)
    end

    it 'has container scanning for registry metadata' do
      visit_container_registry

      within_testid('container-scanning-metadata') do
        content = s_('ContainerRegistry|Container scanning for registry: Off')
        expect(page).to have_content(content)
      end

      find_by_testid('container-scanning-shield-icon').hover

      within_testid('container-scanning-metadata-popover') do
        content = s_(
          'ContainerRegistry|Continuous container scanning runs in the registry when any image or database is updated.'
        )

        expect(page).to have_content(content)
      end
    end
  end

  context 'when container registry config disabled' do
    before do
      stub_container_registry_config(enabled: false)
    end

    it 'does not have container scanning for registry metadata' do
      visit_container_registry

      expect(page).to have_no_content s_('ContainerRegistry|Container scanning for registry: Off')
    end
  end

  def visit_container_registry
    visit project_container_registry_index_path(project)
  end
end
