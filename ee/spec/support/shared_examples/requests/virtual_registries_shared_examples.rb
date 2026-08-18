# frozen_string_literal: true

RSpec.shared_examples 'disallowed access to virtual registry' do
  context 'when group is not root group' do
    let(:group) { create(:group, :private, parent: super()) }

    it_behaves_like 'returning response status', :not_found
  end

  context 'when the dependency proxy config is disabled' do
    before do
      stub_config(dependency_proxy: { enabled: false })
    end

    it_behaves_like 'returning response status', :not_found
  end

  context 'when virtual registries setting enabled is false' do
    before do
      allow(VirtualRegistries::Setting).to receive(:enabled_for_group?).with(group).and_return(false)
    end

    it_behaves_like 'returning response status', :not_found
  end
end

RSpec.shared_examples 'disallowed access to maven virtual registry' do
  it_behaves_like 'disallowed access to virtual registry'

  context 'when license is invalid' do
    before do
      stub_licensed_features(packages_virtual_registry: false)
    end

    it_behaves_like 'returning response status', :not_found
  end

  context 'when feature flag maven_virtual_registry is disabled' do
    before do
      stub_feature_flags(maven_virtual_registry: false)
    end

    it_behaves_like 'returning response status', :not_found
  end
end

RSpec.shared_examples 'disallowed access to container virtual registry' do
  it_behaves_like 'disallowed access to virtual registry'

  context 'when license is invalid' do
    before do
      stub_licensed_features(container_virtual_registry: false)
    end

    it_behaves_like 'returning response status', :not_found
  end

  context 'when feature flag container_virtual_registries is disabled' do
    before do
      stub_feature_flags(container_virtual_registries: false)
    end

    it_behaves_like 'returning response status', :not_found
  end
end
