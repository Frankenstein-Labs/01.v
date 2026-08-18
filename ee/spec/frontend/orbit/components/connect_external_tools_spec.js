import { GlButton } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import ConnectExternalTools from 'ee/orbit/components/connect_external_tools.vue';
import ClipboardButton from '~/vue_shared/components/clipboard_button.vue';

describe('OrbitConnectExternalTools tracking', () => {
  let wrapper;

  const { bindInternalEventDocument } = useMockInternalEventsTracking();

  const createComponent = () => shallowMount(ConnectExternalTools);

  beforeEach(() => {
    wrapper = createComponent();
  });

  it('tracks click_orbit_mcp_quickstart and emits quick-start when the quickstart button is clicked', () => {
    const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

    wrapper.findComponent(GlButton).vm.$emit('click');

    expect(trackEventSpy).toHaveBeenCalledWith('click_orbit_mcp_quickstart', {}, undefined);
    expect(wrapper.emitted('quick-start')).toHaveLength(1);
  });

  it.each([
    ['CLI', 0],
    ['MCP', 1],
  ])(
    'tracks click_orbit_copy_to_clipboard with label %s when the %s button emits click',
    (label, index) => {
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

      wrapper.findAllComponents(ClipboardButton).at(index).vm.$emit('click');

      expect(trackEventSpy).toHaveBeenCalledWith(
        'click_orbit_copy_to_clipboard',
        { label },
        undefined,
      );
    },
  );
});
