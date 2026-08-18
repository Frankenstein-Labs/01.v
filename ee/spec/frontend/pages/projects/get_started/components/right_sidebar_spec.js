import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import RightSidebar from 'ee/pages/projects/get_started/components/right_sidebar.vue';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';

describe('RightSidebar', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMountExtended(RightSidebar);
  };

  const findTitle = () => wrapper.findAll('h2');

  beforeEach(() => {
    createComponent();
  });

  describe('rendering', () => {
    it('renders the correct titles', () => {
      expect(findTitle().at(0).text()).toBe('GitLab University');
      expect(findTitle().at(1).text()).toBe('Learn more');
    });
  });

  describe('with tracking', () => {
    const { bindInternalEventDocument } = useMockInternalEventsTracking();

    it.each(RightSidebar.LEARN_MORE_LINKS.map((link) => [link.trackingLabel]))(
      'tracks clicking %s learn more link',
      async (label) => {
        const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

        await wrapper.findComponentByTestId(`${label}-learn-more-link`).vm.$emit('click');

        expect(trackEventSpy).toHaveBeenCalledWith(
          'click_learn_more_links_in_get_started',
          { label },
          undefined,
        );
      },
    );

    it('tracks clicking enroll button', async () => {
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

      await wrapper.findComponentByTestId('gitlab-university-enroll-link').vm.$emit('click');

      expect(trackEventSpy).toHaveBeenCalledWith(
        'click_enroll_gitlab_university_in_get_started',
        {},
        undefined,
      );
    });
  });
});
