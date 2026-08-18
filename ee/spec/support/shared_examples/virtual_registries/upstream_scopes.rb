# frozen_string_literal: true

# rubocop:disable Rails/SaveBang -- create! does not work here
RSpec.shared_examples 'virtual registry upstream scopes' do |registry_factory:, upstream_factory:|
  describe 'scopes', :aggregate_failures do
    describe '.eager_load_registry_upstream' do
      let_it_be(:registry, freeze: false) { create(registry_factory, :with_upstreams, upstreams_count: 2) }
      let_it_be(:other_registry, freeze: false) { create(registry_factory, :with_upstreams) }

      subject(:upstreams) { described_class.eager_load_registry_upstream(registry:) }

      it { is_expected.to eq(registry.upstreams) }

      it { is_expected.not_to include(other_registry.upstreams) }

      it 'eager loads the registry_upstream association' do
        recorder = ActiveRecord::QueryRecorder.new { upstreams.each(&:registry_upstreams) }

        expect(recorder.count).to eq(1)
      end
    end

    describe '.for_id_and_group' do
      let_it_be(:upstream, freeze: false) { create(upstream_factory) }

      before do
        create(upstream_factory)
      end

      subject { described_class.for_id_and_group(id: upstream.id, group: upstream.group) }

      it { is_expected.to contain_exactly(upstream) }
    end

    describe '.for_group' do
      let_it_be(:group, freeze: false) { create(:group) }
      let_it_be(:upstream, freeze: false) { create(upstream_factory, group:) }
      let_it_be(:other_upstream, freeze: false) { create(upstream_factory) }

      subject { described_class.for_group(group) }

      it { is_expected.to eq([upstream]) }
    end
  end
end
# rubocop:enable Rails/SaveBang
