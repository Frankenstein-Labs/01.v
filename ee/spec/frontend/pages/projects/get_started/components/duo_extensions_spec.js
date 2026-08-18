import { GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import DuoExtensions from 'ee/pages/projects/get_started/components/duo_extensions.vue';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';

describe('DuoExtensions component', () => {
  let wrapper;

  beforeEach(() => {
    wrapper = shallowMountExtended(DuoExtensions);
  });

  it('renders correctly', () => {
    expect(wrapper.element).toMatchSnapshot();
  });

  it('shows extension types', () => {
    expect(wrapper.text()).toContain('VS Code');
    expect(wrapper.text()).toContain('Eclipse');
    expect(wrapper.text()).toContain('GitLab CLI');
  });

  it('extensions link to doc url', () => {
    expect(wrapper.findComponent(GlButton).text()).toContain('VS Code');
    expect(wrapper.findComponent(GlButton).attributes('href')).toBe(
      '/help/editor_extensions/visual_studio_code/setup.md',
    );
  });

  describe('with tracking', () => {
    const { bindInternalEventDocument } = useMockInternalEventsTracking();

    it.each(DuoExtensions.EXTENSIONS.map((ext) => [ext.trackingLabel]))(
      'tracks clicking %s extension download link',
      async (label) => {
        const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

        await wrapper.findComponentByTestId(`${label}-extension-link`).vm.$emit('click');

        expect(trackEventSpy).toHaveBeenCalledWith(
          'click_duo_extension_download_link_in_get_started',
          { label },
          undefined,
        );
      },
    );
  });
});
