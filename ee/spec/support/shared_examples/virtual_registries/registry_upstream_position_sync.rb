# frozen_string_literal: true

RSpec.shared_examples 'registry upstream position sync' do |registry_factory:, registry_upstream_factory:|
  describe '#update_position' do
    let_it_be(:registry, freeze: false) { create(registry_factory) } # rubocop:disable Rails/SaveBang -- return value is used

    let_it_be(:registry_upstreams, freeze: false) do
      create_list(registry_upstream_factory, 4, registry:)
    end

    before do
      registry_upstreams.each { |upstream| upstream.errors.clear }
    end

    context 'when position is invalid' do
      let(:new_position) { 2 }

      subject(:update_position) { registry_upstreams[0].update_position(new_position) }

      context 'when position is less than 1' do
        let(:new_position) { 0 }

        it 'returns false and adds an error' do
          is_expected.to be false
          expect(registry_upstreams[0].errors[:position]).to include(
            a_string_matching(/must be greater than or equal to 1/)
          )
        end

        it 'does not update any positions' do
          expect { update_position }.not_to change { reload_positions }
        end
      end

      context "when position is greater than #{described_class::MAX_UPSTREAMS_COUNT}" do
        let(:new_position) { described_class::MAX_UPSTREAMS_COUNT + 1 }

        it 'returns false and adds an error' do
          is_expected.to be false
          expect(registry_upstreams[0].errors[:position]).to include(
            a_string_matching(/must be less than or equal to #{described_class::MAX_UPSTREAMS_COUNT}/) # rubocop:disable Performance/ConstantRegexp -- /o would memoize the first MAX_UPSTREAMS_COUNT interpolation across the Maven and Container example groups, caching the wrong value
          )
        end

        it 'does not update any positions' do
          expect { update_position }.not_to change { reload_positions }
        end
      end
    end

    context 'when position is unchanged' do
      it 'does not update any positions' do
        expect { registry_upstreams[0].update_position(1) }.not_to change { reload_positions }
      end
    end

    context 'when moving to a lower position' do
      it 'updates the position of the target and increments positions of items in between' do
        registry_upstreams[0].update_position(3)

        expect(reload_positions).to eq({
          registry_upstreams[0].id => 3,
          registry_upstreams[1].id => 1,
          registry_upstreams[2].id => 2,
          registry_upstreams[3].id => 4
        })
      end

      it 'handles moving to the lowest position' do
        registry_upstreams[0].update_position(4)

        expect(reload_positions).to eq({
          registry_upstreams[0].id => 4,
          registry_upstreams[1].id => 1,
          registry_upstreams[2].id => 2,
          registry_upstreams[3].id => 3
        })
      end
    end

    context 'when moving to a higher position' do
      it 'updates the position of the target and decrements positions of items in between' do
        registry_upstreams[3].update_position(2)

        expect(reload_positions).to eq({
          registry_upstreams[0].id => 1,
          registry_upstreams[1].id => 3,
          registry_upstreams[2].id => 4,
          registry_upstreams[3].id => 2
        })
      end

      it 'handles moving to the highest position' do
        registry_upstreams[3].update_position(1)

        expect(reload_positions).to eq({
          registry_upstreams[0].id => 2,
          registry_upstreams[1].id => 3,
          registry_upstreams[2].id => 4,
          registry_upstreams[3].id => 1
        })
      end
    end

    context 'when moving to a position beyond the current count but within max' do
      it 'caps the position at the maximum existing position' do
        registry_upstreams[1].update_position(described_class::MAX_UPSTREAMS_COUNT)

        expect(reload_positions).to eq({
          registry_upstreams[0].id => 1,
          registry_upstreams[1].id => 4,
          registry_upstreams[2].id => 2,
          registry_upstreams[3].id => 3
        })
      end
    end

    context 'when there are multiple registries' do
      let_it_be(:other_registry, freeze: false) { create(:virtual_registries_packages_maven_registry) }
      let_it_be_with_reload(:other_registry_upstreams) do
        create_list(:virtual_registries_packages_maven_registry_upstream, 2, registry: other_registry)
      end

      it 'only updates positions within the same registry' do
        registry_upstreams[0].update_position(3)

        # Positions in the original registry should be updated
        expect(reload_positions).to eq({
          registry_upstreams[0].id => 3,
          registry_upstreams[1].id => 1,
          registry_upstreams[2].id => 2,
          registry_upstreams[3].id => 4
        })

        # Positions in the other registry should remain unchanged
        expect(other_registry_upstreams[0].position).to eq(1)
        expect(other_registry_upstreams[1].position).to eq(2)
      end
    end
  end

  describe '.sync_higher_positions' do
    let_it_be(:registry, freeze: false) { create(registry_factory) } # rubocop:disable Rails/SaveBang -- return value is used

    let_it_be_with_refind(:registry_upstreams) do
      create_list(registry_upstream_factory, 4, registry:)
    end

    it 'decrements positions of all registry upstreams with higher positions' do
      expect(reload_positions).to eq({
        registry_upstreams[0].id => 1,
        registry_upstreams[1].id => 2,
        registry_upstreams[2].id => 3,
        registry_upstreams[3].id => 4
      })

      described_class.sync_higher_positions(registry_upstreams[1].upstream.registry_upstreams)
      registry_upstreams[1].destroy!

      expect(reload_positions).to eq({
        registry_upstreams[0].id => 1,
        registry_upstreams[2].id => 2,
        registry_upstreams[3].id => 3
      })
    end

    context 'when there are shared upstreams' do
      let_it_be(:other_registry, freeze: false) do
        create(registry_factory, group: registry.group, name: 'other')
      end

      let_it_be(:registry_upstream_1, freeze: false) do
        create(registry_upstream_factory, registry: other_registry,
          upstream: registry_upstreams[0].upstream)
      end

      let_it_be(:registry_upstream_2, freeze: false) do
        create(registry_upstream_factory, registry: other_registry,
          upstream: registry_upstreams[1].upstream)
      end

      it 'correctly updates positions in all registries' do
        expect(reload_positions).to eq({
          registry_upstreams[0].id => 1,
          registry_upstreams[1].id => 2,
          registry_upstreams[2].id => 3,
          registry_upstreams[3].id => 4
        })

        expect(reload_positions(other_registry)).to eq({
          registry_upstream_1.id => 1,
          registry_upstream_2.id => 2
        })

        described_class.sync_higher_positions(
          described_class.where(upstream_id: [registry_upstreams[1].upstream_id, registry_upstream_1.upstream_id])
        )
        registry_upstreams[1].destroy!
        registry_upstream_1.destroy!

        expect(reload_positions).to eq({
          registry_upstreams[0].id => 1,
          registry_upstreams[2].id => 2,
          registry_upstreams[3].id => 3
        })

        expect(reload_positions(other_registry)).to eq({
          registry_upstream_2.id => 1
        })
      end
    end
  end

  describe '#sync_higher_positions' do
    let_it_be(:registry, freeze: false) { create(registry_factory) } # rubocop:disable Rails/SaveBang -- return value is used

    let_it_be(:registry_upstreams, freeze: false) do
      create_list(registry_upstream_factory, 4, registry:)
    end

    it 'decrements positions of all registry upstreams with higher positions' do
      expect(reload_positions).to eq({
        registry_upstreams[0].id => 1,
        registry_upstreams[1].id => 2,
        registry_upstreams[2].id => 3,
        registry_upstreams[3].id => 4
      })

      registry_upstreams[1].destroy!
      registry_upstreams[1].sync_higher_positions

      expect(reload_positions).to eq({
        registry_upstreams[0].id => 1,
        registry_upstreams[2].id => 2,
        registry_upstreams[3].id => 3
      })
    end
  end

  def reload_positions(registry = registry_upstreams[0].registry)
    described_class.where(registry:).pluck(:id, :position).to_h
  end
end
