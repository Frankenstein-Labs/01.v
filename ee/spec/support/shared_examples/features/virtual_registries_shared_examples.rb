# frozen_string_literal: true

RSpec.shared_examples 'virtual registry is unavailable' do
  context 'when dependency proxy feature is not available' do
    before do
      stub_config(dependency_proxy: { enabled: false })
    end

    it 'renders 404' do
      visit url

      expect(page).to have_gitlab_http_status(:not_found)
    end
  end

  context 'when group is not root group' do
    let(:group) { create(:group, :private, parent: super()) }

    it 'renders 404' do
      visit url

      expect(page).to have_gitlab_http_status(:not_found)
    end
  end

  context 'when virtual registry setting enabled is false' do
    before do
      allow(VirtualRegistries::Setting).to receive(:find_for_group).with(group).and_return(build_stubbed(
        :virtual_registries_setting, :disabled, group: group))
    end

    it 'renders 404' do
      visit url

      expect(page).to have_gitlab_http_status(:not_found)
    end
  end
end

RSpec.shared_examples 'maven virtual registry is unavailable' do
  it_behaves_like 'virtual registry is unavailable'

  context 'when license is invalid' do
    before do
      stub_licensed_features(packages_virtual_registry: false)
    end

    it 'renders 404' do
      visit url

      expect(page).to have_gitlab_http_status(:not_found)
    end
  end
end

RSpec.shared_examples 'container virtual registry is unavailable' do
  it_behaves_like 'virtual registry is unavailable'

  context 'when license is invalid' do
    before do
      stub_licensed_features(container_virtual_registry: false)
    end

    it 'renders 404' do
      visit url

      expect(page).to have_gitlab_http_status(:not_found)
    end
  end
end
