# frozen_string_literal: true

RSpec.shared_examples 'virtual registries: group registry limit' do |registry_factory:|
  describe '#max_per_group' do
    let(:registry_2) { build(registry_factory, group: registry.group) }
    let(:registry_3) { build(registry_factory, group: registry.group) }

    before do
      registry.save!
    end

    it 'does not allow more than one registry per group' do
      stub_const("#{described_class}::MAX_REGISTRY_COUNT", 1)

      expect(registry_2).to be_invalid
        .and have_attributes(errors: hash_including(base: ['1 registry is the maximum allowed per top-level group.']))
    end

    it 'does not allow more than two registries per group' do
      stub_const("#{described_class}::MAX_REGISTRY_COUNT", 2)

      registry_3.save!

      expect(registry_2).to be_invalid
        .and have_attributes(errors: hash_including(base: ['2 registries is the maximum allowed per top-level group.']))
    end
  end
end
