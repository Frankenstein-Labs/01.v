# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::ProvisioningService, feature_category: :global_search do
  let_it_be(:namespace) { create(:group) }
  let_it_be(:enabled_namespace) do
    create(:zoekt_enabled_namespace, namespace: namespace, last_rollout_failed_at: 1.day.ago.iso8601)
  end

  let_it_be(:namespace2) { create(:group) }
  let_it_be(:enabled_namespace2) { create(:zoekt_enabled_namespace, namespace: namespace2) }
  # `freeze: false` is required here: this `let_it_be` subject is mutated
  # in-memory across examples in a way that survives both
  # `let_it_be_with_reload` and `let_it_be_with_refind` (e.g. a memoized
  # association/collection or a non-persisted attribute). Keeping it unfrozen
  # is the only correct cure (see gitlab-org/gitlab#602925).
  let_it_be(:nodes, freeze: false) { create_list(:zoekt_node, 5, total_bytes: 100.gigabytes, used_bytes: 90.gigabytes) }

  let(:plan) do
    {
      create: [
        {
          namespace_id: namespace.id,
          enabled_namespace_id: enabled_namespace.id,
          action: :create,
          replicas: [
            {
              indices: [
                {
                  node_id: nodes.first.id,
                  required_storage_bytes: 3.gigabytes,
                  max_storage_bytes: 90.gigabytes,
                  projects: { project_namespace_id_from: 1, project_namespace_id_to: 5 }
                },
                {
                  node_id: nodes.second.id,
                  required_storage_bytes: 2.gigabytes,
                  max_storage_bytes: 80.gigabytes,
                  projects: { project_namespace_id_from: 6, project_namespace_id_to: nil }
                }
              ]
            },
            {
              indices: [
                {
                  node_id: nodes.third.id,
                  required_storage_bytes: 3.gigabytes,
                  max_storage_bytes: 90.gigabytes,
                  projects: { project_namespace_id_from: 1, project_namespace_id_to: 5 }
                },
                {
                  node_id: nodes.fourth.id,
                  required_storage_bytes: 2.gigabytes,
                  max_storage_bytes: 80.gigabytes,
                  projects: { project_namespace_id_from: 6, project_namespace_id_to: nil }
                }
              ]
            }
          ],
          errors: [],
          namespace_required_storage_bytes: 10.gigabytes
        },
        {
          namespace_id: namespace2.id,
          enabled_namespace_id: enabled_namespace2.id,
          action: :create,
          replicas: [
            {
              indices: [
                {
                  node_id: nodes.first.id,
                  required_storage_bytes: 2.gigabytes,
                  max_storage_bytes: 90.gigabytes,
                  projects: { project_namespace_id_from: 1, project_namespace_id_to: 3 }
                },
                {
                  node_id: nodes.second.id,
                  required_storage_bytes: 1.gigabyte,
                  max_storage_bytes: 80.gigabytes,
                  projects: { project_namespace_id_from: 4, project_namespace_id_to: nil }
                }
              ]
            },
            {
              indices: [
                {
                  node_id: nodes.third.id,
                  required_storage_bytes: 2.gigabytes,
                  max_storage_bytes: 90.gigabytes,
                  projects: { project_namespace_id_from: 1, project_namespace_id_to: 3 }
                },
                {
                  node_id: nodes.fourth.id,
                  required_storage_bytes: 1.gigabyte,
                  max_storage_bytes: 80.gigabytes,
                  projects: { project_namespace_id_from: 4, project_namespace_id_to: nil }
                }
              ]
            }
          ],
          errors: [],
          namespace_required_storage_bytes: 6.gigabytes
        }
      ],
      destroy: [],
      unchanged: [],
      total_required_storage_bytes: 16.gigabytes,
      failures: []
    }
  end

  subject(:provisioning_result) { described_class.execute(plan) }

  describe '.provision' do
    context 'when the plan is valid' do
      it 'provisions all replicas and indices' do
        result = provisioning_result
        # Ensure there are no errors
        expect(result[:errors]).to be_empty
        expect(enabled_namespace.reload.replicas.count).to eq(2)
        expect(enabled_namespace.indices.count).to eq(4)
        expect(enabled_namespace2.reload.replicas.count).to eq(2)
        expect(enabled_namespace2.indices.count).to eq(4)

        idx_metadata = enabled_namespace.replicas.first.indices.find_by_zoekt_node_id(nodes.first).metadata
        expect(idx_metadata).to eq({ 'project_namespace_id_to' => 5, 'project_namespace_id_from' => 1 })
        idx_metadata2 = enabled_namespace.replicas.first.indices.find_by_zoekt_node_id(nodes.second).metadata
        expect(idx_metadata2).to eq({ 'project_namespace_id_from' => 6 })
        idx_metadata3 = enabled_namespace.replicas.second.indices.find_by_zoekt_node_id(nodes.third).metadata
        expect(idx_metadata3).to eq({ 'project_namespace_id_to' => 5, 'project_namespace_id_from' => 1 })
        idx_metadata4 = enabled_namespace.replicas.second.indices.find_by_zoekt_node_id(nodes.fourth).metadata
        expect(idx_metadata4).to eq({ 'project_namespace_id_from' => 6 })
        idx_metadata5 = enabled_namespace2.replicas.first.indices.find_by_zoekt_node_id(nodes.first).metadata
        expect(idx_metadata5).to eq({ 'project_namespace_id_to' => 3, 'project_namespace_id_from' => 1 })
        idx_metadata6 = enabled_namespace2.replicas.first.indices.find_by_zoekt_node_id(nodes.second).metadata
        expect(idx_metadata6).to eq({ 'project_namespace_id_from' => 4 })
        idx_metadata7 = enabled_namespace2.replicas.second.indices.find_by_zoekt_node_id(nodes.third).metadata
        expect(idx_metadata7).to eq({ 'project_namespace_id_to' => 3, 'project_namespace_id_from' => 1 })
        index = enabled_namespace2.replicas.second.indices.find_by_zoekt_node_id(nodes.fourth)
        idx_metadata8 = index.metadata
        expect(idx_metadata8).to eq({ 'project_namespace_id_from' => 4 })
        expect(index.reserved_storage_bytes).to eq(1.gigabyte)
        expect(result[:success].size).to eq(4)
        expect(enabled_namespace.last_rollout_failed_at).to be_nil
      end
    end

    context 'when there is not enough space in node' do
      before do
        nodes.second.update!(used_bytes: 99.gigabytes) # Simulate node being near full
      end

      it 'accumulates the error and provisions other replicas that don\'t use that node', :freeze_time do
        result = provisioning_result
        expect(result[:errors]).to include(
          a_hash_including(
            message: 'node_capacity_exceeded',
            failed_namespace_id: namespace.id,
            node_id: nodes.second.id,
            node_name: nodes.second.metadata['name']
          )
        )
        # Since the second replica for namespace succeeds, last_rollout_failed_at should be reset
        expect(enabled_namespace.reload.last_rollout_failed_at).to be_nil
      end
    end

    context 'when there is an error initializing a replica' do
      it 'accumulates the error and does not creates anything', :freeze_time do
        allow(::Search::Zoekt::Replica).to receive(:new).and_raise(StandardError, 'Replica initialization failed')

        result = provisioning_result

        expect(result[:errors]).to include(a_hash_including(message: 'Replica initialization failed'))
        expect(Search::Zoekt::Replica.count).to be_zero
        expect(Search::Zoekt::Index.count).to be_zero
        expect(result[:success]).to be_empty
        expect(enabled_namespace.reload.last_rollout_failed_at).to eq(Time.current.iso8601)
      end
    end

    context 'when namespace plan has no replicas' do
      let(:plan) do
        {
          create: [
            {
              namespace_id: namespace.id,
              enabled_namespace_id: enabled_namespace.id,
              action: :create,
              replicas: [],
              errors: [],
              namespace_required_storage_bytes: 0
            }
          ],
          destroy: [],
          unchanged: [],
          total_required_storage_bytes: 0,
          failures: []
        }
      end

      it 'does not update enabled_namespace failure timestamp when there are no replicas' do
        # Capture the value before the test runs
        initial_failed_at = enabled_namespace.reload.last_rollout_failed_at

        result = provisioning_result

        expect(result[:errors]).to be_empty
        expect(result[:success]).to be_empty
        expect(Search::Zoekt::Replica.count).to be_zero
        # last_rollout_failed_at should remain unchanged when total_replicas is 0
        expect(enabled_namespace.reload.last_rollout_failed_at).to eq(initial_failed_at)
      end
    end

    context 'when one index can not be created among multiple indices from the plan' do
      let(:plan) do
        {
          create: [
            {
              namespace_id: namespace.id,
              enabled_namespace_id: enabled_namespace.id,
              action: :create,
              replicas: [
                {
                  indices: [
                    {
                      node_id: non_existing_record_id,
                      node_name: 'phantom-node',
                      required_storage_bytes: 3.gigabytes,
                      max_storage_bytes: 90.gigabytes,
                      projects: { project_namespace_id_from: 1, project_namespace_id_to: 5 }
                    },
                    {
                      node_id: nodes.second.id,
                      required_storage_bytes: 2.gigabytes,
                      max_storage_bytes: 80.gigabytes,
                      projects: { project_namespace_id_from: 6, project_namespace_id_to: nil }
                    }
                  ]
                },
                {
                  indices: [
                    {
                      node_id: nodes.third.id,
                      required_storage_bytes: 3.gigabytes,
                      max_storage_bytes: 90.gigabytes,
                      projects: { project_namespace_id_from: 1, project_namespace_id_to: 5 }
                    },
                    {
                      node_id: nodes.fourth.id,
                      required_storage_bytes: 2.gigabytes,
                      max_storage_bytes: 80.gigabytes,
                      projects: { project_namespace_id_from: 6, project_namespace_id_to: nil }
                    }
                  ]
                }
              ],
              errors: [],
              namespace_required_storage_bytes: 10.gigabytes
            },
            {
              namespace_id: namespace2.id,
              enabled_namespace_id: enabled_namespace2.id,
              action: :create,
              replicas: [
                {
                  indices: [
                    {
                      node_id: nodes.first.id,
                      required_storage_bytes: 2.gigabytes,
                      max_storage_bytes: 90.gigabytes,
                      projects: { project_namespace_id_from: 1, project_namespace_id_to: 3 }
                    },
                    {
                      node_id: nodes.second.id,
                      required_storage_bytes: 1.gigabyte,
                      max_storage_bytes: 80.gigabytes,
                      projects: { project_namespace_id_from: 4, project_namespace_id_to: nil }
                    }
                  ]
                },
                {
                  indices: [
                    {
                      node_id: nodes.third.id,
                      required_storage_bytes: 2.gigabytes,
                      max_storage_bytes: 90.gigabytes,
                      projects: { project_namespace_id_from: 1, project_namespace_id_to: 3 }
                    },
                    {
                      node_id: nodes.fourth.id,
                      required_storage_bytes: 1.gigabyte,
                      max_storage_bytes: 80.gigabytes,
                      projects: { project_namespace_id_from: 4, project_namespace_id_to: nil }
                    }
                  ]
                }
              ],
              errors: [],
              namespace_required_storage_bytes: 6.gigabytes
            }
          ],
          destroy: [],
          unchanged: [],
          total_required_storage_bytes: 16.gigabytes,
          failures: []
        }
      end

      it 'is atomic per replica, not per namespace', :freeze_time do
        result = provisioning_result
        expect(result[:errors]).to include(
          a_hash_including(
            message: 'node_not_found',
            failed_namespace_id: namespace.id,
            node_id: non_existing_record_id,
            node_name: 'phantom-node'
          )
        )
        expect(result[:success]).to include(a_hash_including(namespace_id: namespace2.id))
        # The second replica for namespace should succeed even though the first replica failed
        expect(enabled_namespace.replicas.count).to eq(1)
        # Since at least one replica succeeded, last_rollout_failed_at should be reset
        expect(enabled_namespace.reload.last_rollout_failed_at).to be_nil
        expect(enabled_namespace2.replicas).not_to be_empty
        # Only the successful replica's indices should be created
        expect(enabled_namespace.indices.count).to eq(2)
        expect(enabled_namespace2.indices).not_to be_empty
        expect(result[:success].size).to eq(3)
      end
    end

    context 'when one index reserved_storage_bytes is not sufficient at the time of indices creation', :freeze_time do
      let(:plan) do
        {
          create: [
            {
              namespace_id: namespace.id,
              enabled_namespace_id: enabled_namespace.id,
              action: :create,
              replicas: [
                {
                  indices: [
                    {
                      node_id: nodes.first.id,
                      required_storage_bytes: 11.gigabytes,
                      max_storage_bytes: 90.gigabytes,
                      projects: { project_namespace_id_from: 1, project_namespace_id_to: 5 }
                    },
                    {
                      node_id: nodes.second.id,
                      required_storage_bytes: 2.gigabytes,
                      max_storage_bytes: 80.gigabytes,
                      projects: { project_namespace_id_from: 6, project_namespace_id_to: nil }
                    }
                  ]
                },
                {
                  indices: [
                    {
                      node_id: nodes.third.id,
                      required_storage_bytes: 3.gigabytes,
                      max_storage_bytes: 90.gigabytes,
                      projects: { project_namespace_id_from: 1, project_namespace_id_to: 5 }
                    },
                    {
                      node_id: nodes.fourth.id,
                      required_storage_bytes: 2.gigabytes,
                      max_storage_bytes: 80.gigabytes,
                      projects: { project_namespace_id_from: 6, project_namespace_id_to: nil }
                    }
                  ]
                }
              ],
              errors: [],
              namespace_required_storage_bytes: 16.gigabytes
            },
            {
              namespace_id: namespace2.id,
              enabled_namespace_id: enabled_namespace2.id,
              action: :create,
              replicas: [
                {
                  indices: [
                    {
                      node_id: nodes.first.id,
                      required_storage_bytes: 2.gigabytes,
                      max_storage_bytes: 90.gigabytes,
                      projects: { project_namespace_id_from: 1, project_namespace_id_to: 3 }
                    },
                    {
                      node_id: nodes.second.id,
                      required_storage_bytes: 1.gigabyte,
                      max_storage_bytes: 80.gigabytes,
                      projects: { project_namespace_id_from: 4, project_namespace_id_to: nil }
                    }
                  ]
                },
                {
                  indices: [
                    {
                      node_id: nodes.third.id,
                      required_storage_bytes: 2.gigabytes,
                      max_storage_bytes: 90.gigabytes,
                      projects: { project_namespace_id_from: 1, project_namespace_id_to: 3 }
                    },
                    {
                      node_id: nodes.fourth.id,
                      required_storage_bytes: 1.gigabyte,
                      max_storage_bytes: 80.gigabytes,
                      projects: { project_namespace_id_from: 4, project_namespace_id_to: nil }
                    }
                  ]
                }
              ],
              errors: [],
              namespace_required_storage_bytes: 6.gigabytes
            }
          ],
          destroy: [],
          unchanged: [],
          total_required_storage_bytes: 16.gigabytes,
          failures: []
        }
      end

      it 'skips the failed replica and continues with other replicas' do
        result = provisioning_result
        expect(result[:errors]).to include(
          a_hash_including(
            message: 'node_capacity_exceeded',
            failed_namespace_id: namespace.id,
            node_id: nodes.first.id,
            node_name: nodes.first.metadata['name']
          )
        )
        # Since at least one replica succeeded, last_rollout_failed_at should be reset
        expect(enabled_namespace.reload.last_rollout_failed_at).to be_nil
        expect(enabled_namespace.metadata['rollout_required_storage_bytes']).to be_nil
        expect(result[:success]).to include(a_hash_including(namespace_id: namespace2.id))
        # The second replica for namespace should succeed even though the first replica failed
        expect(enabled_namespace.replicas.count).to eq(1)
        expect(enabled_namespace2.replicas).not_to be_empty
        # Only the successful replica's indices should be created
        expect(enabled_namespace.indices.count).to eq(2)
        expect(enabled_namespace2.indices).not_to be_empty
        expect(result[:success].size).to eq(3)
      end
    end

    context 'when a namespace has errors in its plan' do
      let(:plan) do
        {
          create: [
            {
              namespace_id: namespace2.id,
              enabled_namespace_id: enabled_namespace2.id,
              action: :create,
              replicas: [
                {
                  indices: [
                    {
                      node_id: nodes.first.id,
                      required_storage_bytes: 2.gigabytes,
                      max_storage_bytes: 90.gigabytes,
                      projects: { project_namespace_id_from: 1, project_namespace_id_to: 3 }
                    },
                    {
                      node_id: nodes.second.id,
                      required_storage_bytes: 1.gigabyte,
                      max_storage_bytes: 80.gigabytes,
                      projects: { project_namespace_id_from: 4, project_namespace_id_to: nil }
                    }
                  ]
                },
                {
                  indices: [
                    {
                      node_id: nodes.third.id,
                      required_storage_bytes: 2.gigabytes,
                      max_storage_bytes: 90.gigabytes,
                      projects: { project_namespace_id_from: 1, project_namespace_id_to: 3 }
                    },
                    {
                      node_id: nodes.fourth.id,
                      required_storage_bytes: 1.gigabyte,
                      max_storage_bytes: 80.gigabytes,
                      projects: { project_namespace_id_from: 4, project_namespace_id_to: nil }
                    }
                  ]
                }
              ],
              errors: [],
              namespace_required_storage_bytes: 6.gigabytes
            }
          ],
          total_required_storage_bytes: 16.gigabytes,
          failures: [
            {
              namespace_id: namespace.id,
              enabled_namespace_id: enabled_namespace.id,
              replicas: [
                {
                  indices: [
                    {
                      node_id: nodes.first.id,
                      required_storage_bytes: 3.gigabytes,
                      max_storage_bytes: 90.gigabytes,
                      projects: { project_namespace_id_from: 1, project_namespace_id_to: 5 }
                    },
                    {
                      node_id: nodes.second.id,
                      required_storage_bytes: 2.gigabytes,
                      max_storage_bytes: 80.gigabytes,
                      projects: { project_namespace_id_from: 6, project_namespace_id_to: nil }
                    }
                  ]
                },
                {
                  indices: [
                    {
                      node_id: nodes.third.id,
                      required_storage_bytes: 3.gigabytes,
                      max_storage_bytes: 90.gigabytes,
                      projects: { project_namespace_id_from: 1, project_namespace_id_to: 5 }
                    },
                    {
                      node_id: nodes.fourth.id,
                      required_storage_bytes: 2.gigabytes,
                      max_storage_bytes: 80.gigabytes,
                      projects: { project_namespace_id_from: 6, project_namespace_id_to: nil }
                    }
                  ]
                }
              ],
              errors: [{ namespace_id: namespace.id, replica_idx: nil, type: :error_type, details: 'Detail' }],
              namespace_required_storage_bytes: 10.gigabytes
            }
          ],
          destroy: [],
          unchanged: []
        }
      end

      it 'skips that namespace, set metadata on enabled_namespace and continues with the rest', :freeze_time do
        result = provisioning_result
        # Ensure there are no errors
        expect(result[:errors]).to be_empty
        expect(enabled_namespace.replicas).to be_empty
        expect(enabled_namespace.indices).to be_empty
        expect(enabled_namespace.reload.last_rollout_failed_at).to eq(Time.current.iso8601)
        expect(enabled_namespace.metadata['rollout_required_storage_bytes']).to eq(10.gigabytes)
        expect(enabled_namespace2.replicas.count).to eq(2)
        expect(enabled_namespace2.indices.count).to eq(4)
        metadata = enabled_namespace2.replicas.first.indices.find_by_zoekt_node_id(nodes.first).metadata
        expect(metadata).to eq({ 'project_namespace_id_to' => 3, 'project_namespace_id_from' => 1 })
        metadata2 = enabled_namespace2.replicas.first.indices.find_by_zoekt_node_id(nodes.second).metadata
        expect(metadata2).to eq({ 'project_namespace_id_from' => 4 })
        metadata3 = enabled_namespace2.replicas.second.indices.find_by_zoekt_node_id(nodes.third).metadata
        expect(metadata3).to eq({ 'project_namespace_id_to' => 3, 'project_namespace_id_from' => 1 })
        metadata4 = enabled_namespace2.replicas.second.indices.find_by_zoekt_node_id(nodes.fourth).metadata
        expect(metadata4).to eq({ 'project_namespace_id_from' => 4 })
        expect(result[:success].size).to eq(2)
      end
    end

    context 'when namespace is not found' do
      let(:plan) do
        {
          create: [
            {
              namespace_id: non_existing_record_id,
              enabled_namespace_id: enabled_namespace.id,
              action: :create,
              replicas: [
                {
                  indices: [
                    {
                      node_id: nodes.first.id,
                      required_storage_bytes: 3.gigabytes,
                      max_storage_bytes: 90.gigabytes,
                      projects: { project_namespace_id_from: 1, project_namespace_id_to: 5 }
                    }
                  ]
                }
              ],
              errors: [],
              namespace_required_storage_bytes: 3.gigabytes
            },
            {
              namespace_id: namespace2.id,
              enabled_namespace_id: enabled_namespace2.id,
              replicas: [
                {
                  indices: [
                    {
                      node_id: nodes.first.id,
                      required_storage_bytes: 2.gigabytes,
                      max_storage_bytes: 90.gigabytes,
                      projects: { project_namespace_id_from: 1, project_namespace_id_to: 3 }
                    }
                  ]
                }
              ],
              errors: [],
              namespace_required_storage_bytes: 2.gigabytes
            }
          ],
          destroy: [],
          unchanged: [],
          total_required_storage_bytes: 5.gigabytes,
          failures: []
        }
      end

      it 'skips that non existing enabled_namespace and continues with the rest', :freeze_time do
        result = provisioning_result
        expect(result[:errors]).to include(
          a_hash_including(
            message: :missing_enabled_namespace, failed_namespace_id: non_existing_record_id
          )
        )
        expect(result[:success]).to include(a_hash_including(namespace_id: namespace2.id))
      end
    end

    context 'when multiple replicas need to be created' do
      let_it_be(:namespace3) { create(:group) }
      let_it_be(:enabled_namespace3) do
        create(:zoekt_enabled_namespace, namespace: namespace3, number_of_replicas_override: 3)
      end

      let_it_be(:existing_replica) do
        create(:zoekt_replica, namespace_id: namespace3.id, zoekt_enabled_namespace: enabled_namespace3)
      end

      let_it_be(:existing_index) do
        create(:zoekt_index,
          replica: existing_replica,
          zoekt_enabled_namespace: enabled_namespace3,
          node: nodes.first,
          metadata: { 'project_namespace_id_to' => 10, 'project_namespace_id_from' => 1 },
          reserved_storage_bytes: 2.gigabytes
        )
      end

      let(:plan) do
        {
          create: [
            {
              namespace_id: namespace3.id,
              enabled_namespace_id: enabled_namespace3.id,
              action: :create,
              replicas: [
                {
                  indices: [
                    {
                      node_id: nodes.second.id,
                      required_storage_bytes: 2.gigabytes,
                      max_storage_bytes: 80.gigabytes,
                      projects: { project_namespace_id_from: 1, project_namespace_id_to: 10 }
                    }
                  ]
                },
                {
                  indices: [
                    {
                      node_id: nodes.third.id,
                      required_storage_bytes: 2.gigabytes,
                      max_storage_bytes: 90.gigabytes,
                      projects: { project_namespace_id_from: 1, project_namespace_id_to: 10 }
                    }
                  ]
                }
              ],
              errors: [],
              namespace_required_storage_bytes: 4.gigabytes
            }
          ],
          destroy: [],
          unchanged: [],
          total_required_storage_bytes: 4.gigabytes,
          failures: []
        }
      end

      it 'creates the additional replicas to reach the desired number_of_replicas' do
        expect(enabled_namespace3.number_of_replicas).to eq(3)
        expect(enabled_namespace3.reload.replicas.count).to eq(1)

        result = provisioning_result

        expect(result[:errors]).to be_empty
        expect(enabled_namespace3.reload.replicas.count).to eq(3)
        expect(enabled_namespace3.indices.count).to eq(3)

        # Verify each replica has one index
        enabled_namespace3.replicas.each do |replica|
          expect(replica.indices.count).to eq(1)
        end

        # Verify indices are on different nodes
        node_ids = enabled_namespace3.indices.pluck(:zoekt_node_id)
        expect(node_ids).to contain_exactly(nodes.first.id, nodes.second.id, nodes.third.id)

        # Verify metadata is correct for all indices
        enabled_namespace3.indices.each do |index|
          expect(index.metadata).to eq({ 'project_namespace_id_to' => 10, 'project_namespace_id_from' => 1 })
          expect(index.reserved_storage_bytes).to eq(2.gigabytes)
        end

        # Result contains only the newly created replicas
        expect(result[:success].size).to eq(2)
      end
    end

    context 'when index is already present for a namespace' do
      let_it_be(:index) { create(:zoekt_index, zoekt_enabled_namespace: enabled_namespace) }
      let(:plan) do
        {
          create: [
            {
              namespace_id: namespace.id,
              enabled_namespace_id: enabled_namespace.id,
              action: :create,
              replicas: [
                {
                  indices: [
                    {
                      node_id: nodes.first.id,
                      required_storage_bytes: 3.gigabytes,
                      max_storage_bytes: 90.gigabytes,
                      projects: { project_namespace_id_from: 1, project_namespace_id_to: 5 }
                    }
                  ]
                }
              ],
              errors: [],
              namespace_required_storage_bytes: 3.gigabytes
            },
            {
              namespace_id: namespace2.id,
              enabled_namespace_id: enabled_namespace2.id,
              replicas: [
                {
                  indices: [
                    {
                      node_id: nodes.first.id,
                      required_storage_bytes: 2.gigabytes,
                      max_storage_bytes: 90.gigabytes,
                      projects: { project_namespace_id_from: 1, project_namespace_id_to: 3 }
                    }
                  ]
                }
              ],
              errors: [],
              namespace_required_storage_bytes: 2.gigabytes
            }
          ],
          destroy: [],
          unchanged: [],
          total_required_storage_bytes: 5.gigabytes,
          failures: []
        }
      end

      it 'skips the namespace which already has index and continues with the rest', :freeze_time do
        result = provisioning_result
        # With the new incremental provisioning, orphaned indices don't prevent creating new replicas
        expect(result[:errors]).to be_empty
        expect(enabled_namespace.reload.last_rollout_failed_at).to be_nil
        expect(result[:success]).to include(a_hash_including(namespace_id: namespace2.id))
        expect(result[:success]).to include(a_hash_including(namespace_id: namespace.id))
      end
    end

    context 'when plan contains destroy actions' do
      let_it_be(:namespace_to_scale_down) { create(:group) }
      let_it_be(:enabled_namespace_scale_down) do
        create(:zoekt_enabled_namespace, namespace: namespace_to_scale_down, number_of_replicas_override: 2)
      end

      let_it_be(:replicas_to_remove) do
        create_list(:zoekt_replica, 3,
          namespace_id: namespace_to_scale_down.id,
          zoekt_enabled_namespace: enabled_namespace_scale_down
        )
      end

      let_it_be(:_replica_indices) do
        create(:zoekt_index, replica: replicas_to_remove[0], zoekt_enabled_namespace: enabled_namespace_scale_down,
          node: nodes.first)
        create(:zoekt_index, replica: replicas_to_remove[1], zoekt_enabled_namespace: enabled_namespace_scale_down,
          node: nodes.second)
        create(:zoekt_index, replica: replicas_to_remove[2], zoekt_enabled_namespace: enabled_namespace_scale_down,
          node: nodes.third)
      end

      let(:plan) do
        {
          create: [],
          destroy: [
            {
              namespace_id: namespace_to_scale_down.id,
              enabled_namespace_id: enabled_namespace_scale_down.id,
              action: :destroy,
              replicas_to_destroy: [replicas_to_remove[0].id, replicas_to_remove[1].id]
            }
          ],
          unchanged: [],
          total_required_storage_bytes: 0,
          failures: []
        }
      end

      it 'destroys the specified replicas' do
        expect(enabled_namespace_scale_down.replicas.count).to eq(3)

        result = provisioning_result

        expect(result[:errors]).to be_empty
        expect(enabled_namespace_scale_down.reload.replicas.count).to eq(1)

        # Verify the correct replicas were deleted
        remaining_replica_ids = enabled_namespace_scale_down.replicas.pluck(:id)
        expect(remaining_replica_ids).to contain_exactly(replicas_to_remove[2].id)
      end

      it 'includes success information about destroyed replicas' do
        result = provisioning_result

        expect(result[:success].size).to eq(1)
        expect(result[:success].first).to include(
          namespace_id: namespace_to_scale_down.id,
          replicas_destroyed: 2
        )
      end
    end

    context 'when plan contains both create and destroy actions' do
      let_it_be(:create_namespace) { create(:group) }
      let_it_be(:enabled_namespace_create) { create(:zoekt_enabled_namespace, namespace: create_namespace) }

      let_it_be(:destroy_namespace) { create(:group) }
      let_it_be(:enabled_namespace_destroy) do
        create(:zoekt_enabled_namespace, namespace: destroy_namespace, number_of_replicas_override: 1)
      end

      let_it_be(:replicas_destroy) do
        create_list(:zoekt_replica, 3,
          namespace_id: destroy_namespace.id,
          zoekt_enabled_namespace: enabled_namespace_destroy
        )
      end

      let(:plan) do
        {
          create: [
            {
              namespace_id: create_namespace.id,
              enabled_namespace_id: enabled_namespace_create.id,
              action: :create,
              replicas: [
                {
                  indices: [
                    {
                      node_id: nodes.first.id,
                      required_storage_bytes: 2.gigabytes,
                      max_storage_bytes: 90.gigabytes,
                      projects: { project_namespace_id_from: 1, project_namespace_id_to: 5 }
                    }
                  ]
                }
              ],
              errors: [],
              namespace_required_storage_bytes: 2.gigabytes
            }
          ],
          destroy: [
            {
              namespace_id: destroy_namespace.id,
              enabled_namespace_id: enabled_namespace_destroy.id,
              action: :destroy,
              replicas_to_destroy: [replicas_destroy[0].id, replicas_destroy[1].id]
            }
          ],
          unchanged: [],
          total_required_storage_bytes: 2.gigabytes,
          failures: []
        }
      end

      it 'processes both create and destroy actions successfully' do
        expect(enabled_namespace_create.replicas.count).to eq(0)
        expect(enabled_namespace_destroy.replicas.count).to eq(3)

        result = provisioning_result

        expect(result[:errors]).to be_empty
        expect(enabled_namespace_create.reload.replicas.count).to eq(1)
        expect(enabled_namespace_destroy.reload.replicas.count).to eq(1)

        # Verify success includes both operations
        expect(result[:success].size).to eq(2)
        expect(result[:success]).to include(a_hash_including(namespace_id: create_namespace.id, replica_id: anything))
        expect(result[:success]).to include(a_hash_including(namespace_id: destroy_namespace.id, replicas_destroyed: 2))
      end
    end

    context 'when plan includes unchanged namespaces' do
      let_it_be(:unchanged_namespace) { create(:group) }
      let_it_be(:enabled_namespace_unchanged) do
        create(:zoekt_enabled_namespace, namespace: unchanged_namespace, number_of_replicas_override: 2)
      end

      let_it_be(:_unchanged_replicas) do
        create_list(:zoekt_replica, 2,
          namespace_id: unchanged_namespace.id,
          zoekt_enabled_namespace: enabled_namespace_unchanged
        )
      end

      let(:plan) do
        {
          create: [],
          destroy: [],
          unchanged: [
            {
              namespace_id: unchanged_namespace.id,
              enabled_namespace_id: enabled_namespace_unchanged.id,
              action: :unchanged
            }
          ],
          total_required_storage_bytes: 0,
          failures: []
        }
      end

      it 'does not modify unchanged namespaces' do
        expect(enabled_namespace_unchanged.replicas.count).to eq(2)

        result = provisioning_result

        expect(result[:errors]).to be_empty
        expect(result[:success]).to be_empty
        expect(enabled_namespace_unchanged.reload.replicas.count).to eq(2)
      end
    end

    context 'when destroy action references non-existent replicas' do
      let_it_be(:namespace_bad_destroy) { create(:group) }
      let_it_be(:enabled_namespace_bad_destroy) do
        create(:zoekt_enabled_namespace, namespace: namespace_bad_destroy)
      end

      let_it_be(:_existing_replica_only) do
        create(:zoekt_replica,
          namespace_id: namespace_bad_destroy.id,
          zoekt_enabled_namespace: enabled_namespace_bad_destroy
        )
      end

      let(:plan) do
        {
          create: [],
          destroy: [
            {
              namespace_id: namespace_bad_destroy.id,
              enabled_namespace_id: enabled_namespace_bad_destroy.id,
              action: :destroy,
              replicas_to_destroy: [non_existing_record_id, non_existing_record_id + 1]
            }
          ],
          unchanged: [],
          total_required_storage_bytes: 0,
          failures: []
        }
      end

      it 'handles gracefully when replica IDs do not exist' do
        expect(enabled_namespace_bad_destroy.replicas.count).to eq(1)

        result = provisioning_result

        expect(result[:errors]).to be_empty
        # No replicas should be deleted since the IDs don't exist
        expect(enabled_namespace_bad_destroy.reload.replicas.count).to eq(1)

        # Success should not include this namespace since nothing was deleted
        expect(result[:success]).to be_empty
      end
    end

    context 'when destroy action has empty replicas_to_destroy list' do
      let_it_be(:namespace_empty_destroy) { create(:group) }
      let_it_be(:enabled_namespace_empty_destroy) do
        create(:zoekt_enabled_namespace, namespace: namespace_empty_destroy)
      end

      let_it_be(:_existing_replicas_empty) do
        create_list(:zoekt_replica, 2,
          namespace_id: namespace_empty_destroy.id,
          zoekt_enabled_namespace: enabled_namespace_empty_destroy
        )
      end

      let(:plan) do
        {
          create: [],
          destroy: [
            {
              namespace_id: namespace_empty_destroy.id,
              enabled_namespace_id: enabled_namespace_empty_destroy.id,
              action: :destroy,
              replicas_to_destroy: []
            }
          ],
          unchanged: [],
          total_required_storage_bytes: 0,
          failures: []
        }
      end

      it 'handles empty replicas_to_destroy list gracefully' do
        expect(enabled_namespace_empty_destroy.replicas.count).to eq(2)

        result = provisioning_result

        expect(result[:errors]).to be_empty
        expect(enabled_namespace_empty_destroy.reload.replicas.count).to eq(2)
        expect(result[:success]).to be_empty
      end
    end

    context 'when destroy action cannot find enabled_namespace' do
      let(:plan) do
        {
          create: [],
          destroy: [
            {
              namespace_id: non_existing_record_id,
              enabled_namespace_id: non_existing_record_id,
              action: :destroy,
              replicas_to_destroy: [1, 2, 3]
            }
          ],
          unchanged: [],
          total_required_storage_bytes: 0,
          failures: []
        }
      end

      it 'accumulates an error for missing enabled_namespace' do
        result = provisioning_result

        expect(result[:errors]).to include(
          a_hash_including(
            message: :missing_enabled_namespace,
            failed_namespace_id: non_existing_record_id
          )
        )
        expect(result[:success]).to be_empty
      end
    end

    context 'when plan is completely empty' do
      let(:plan) do
        {
          create: [],
          destroy: [],
          unchanged: [],
          total_required_storage_bytes: 0,
          failures: []
        }
      end

      it 'completes successfully with no operations' do
        result = provisioning_result

        expect(result[:errors]).to be_empty
        expect(result[:success]).to be_empty
      end
    end

    context 'when destroy action raises an unexpected error' do
      let_it_be(:namespace_destroy_error) { create(:group) }
      let_it_be(:enabled_namespace_destroy_error) do
        create(:zoekt_enabled_namespace, namespace: namespace_destroy_error)
      end

      let_it_be(:replicas_error) do
        create_list(:zoekt_replica, 2,
          namespace_id: namespace_destroy_error.id,
          zoekt_enabled_namespace: enabled_namespace_destroy_error
        )
      end

      let(:plan) do
        {
          create: [],
          destroy: [
            {
              namespace_id: namespace_destroy_error.id,
              enabled_namespace_id: enabled_namespace_destroy_error.id,
              action: :destroy,
              replicas_to_destroy: [replicas_error.first.id]
            }
          ],
          unchanged: [],
          total_required_storage_bytes: 0,
          failures: []
        }
      end

      it 'captures and aggregates the error' do
        allow(Search::Zoekt::EnabledNamespace).to receive(:find_by_root_namespace_id)
          .and_raise(StandardError, 'Unexpected database error')

        result = provisioning_result

        expect(result[:errors]).to include(
          a_hash_including(
            message: 'Unexpected database error',
            failed_namespace_id: namespace_destroy_error.id
          )
        )
      end
    end
  end
end
