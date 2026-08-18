import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlModal } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import createMockApollo from 'helpers/mock_apollo_helper';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import waitForPromises from 'helpers/wait_for_promises';
import TurnOnIndexingModal from 'ee/orbit/components/turn_on_indexing_modal.vue';
import orbitUpdateMutation from 'ee/orbit/graphql/mutations/orbit_update.mutation.graphql';

Vue.use(VueApollo);

describe('TurnOnIndexingModal tracking', () => {
  let wrapper;
  let mutateHandler;

  const { bindInternalEventDocument } = useMockInternalEventsTracking();

  const group = { name: 'Group A', fullPath: 'group-a' };

  const createComponent = ({ mutateResult } = {}) => {
    mutateHandler = jest
      .fn()
      .mockResolvedValue(mutateResult ?? { data: { orbitUpdate: { errors: [] } } });
    const apolloProvider = createMockApollo([[orbitUpdateMutation, mutateHandler]]);

    wrapper = shallowMount(TurnOnIndexingModal, {
      apolloProvider,
      propsData: { group },
    });
  };

  const findModal = () => wrapper.findComponent(GlModal);

  it('tracks dismiss_orbit_turn_on_modal when the modal is dismissed without confirming', () => {
    createComponent();
    const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

    findModal().vm.$emit('hidden');

    expect(trackEventSpy).toHaveBeenCalledWith('dismiss_orbit_turn_on_modal', {}, undefined);
  });

  it('does not track dismiss when the modal closes after a successful confirm', async () => {
    createComponent();
    const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

    findModal().vm.$emit('primary', { preventDefault: jest.fn() });
    await waitForPromises();
    findModal().vm.$emit('hidden');

    expect(trackEventSpy).not.toHaveBeenCalledWith(
      'dismiss_orbit_turn_on_modal',
      expect.anything(),
      expect.anything(),
    );
  });

  it('tracks dismiss again on the next group after a prior confirm', async () => {
    createComponent();
    const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

    findModal().vm.$emit('primary', { preventDefault: jest.fn() });
    await waitForPromises();
    findModal().vm.$emit('hidden');

    await wrapper.setProps({ group: { name: 'Group B', fullPath: 'group-b' } });
    await nextTick();

    findModal().vm.$emit('hidden');

    expect(trackEventSpy).toHaveBeenCalledWith('dismiss_orbit_turn_on_modal', {}, undefined);
  });
});
