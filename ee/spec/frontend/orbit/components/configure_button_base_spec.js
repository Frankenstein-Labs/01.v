import { GlDisclosureDropdown } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import ConfigureButtonBase from 'ee/orbit/components/configure_button_base.vue';

describe('OrbitConfigureButtonBase tracking', () => {
  let wrapper;

  const { bindInternalEventDocument } = useMockInternalEventsTracking();

  const createComponent = () =>
    shallowMount(ConfigureButtonBase, {
      propsData: {
        namespaces: [
          {
            name: 'Group A',
            fullName: 'Group A',
            fullPath: 'group-a',
            knowledgeGraphEnabled: true,
          },
        ],
      },
    });

  const selectFirstItem = () => {
    wrapper.findComponent(GlDisclosureDropdown).props('items')[0].items[0].action();
  };

  beforeEach(() => {
    wrapper = createComponent();
  });

  it('tracks click_orbit_configure_group when a group is selected', () => {
    const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

    selectFirstItem();

    expect(trackEventSpy).toHaveBeenCalledWith('click_orbit_configure_group', {}, undefined);
  });

  it('emits select with the group fullPath', () => {
    selectFirstItem();

    expect(wrapper.emitted('select')).toEqual([['group-a']]);
  });
});
