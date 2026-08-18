import { GlAlert } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import DisabledSection from 'ee/security_orchestration/components/policy_editor/disabled_section.vue';

describe('DisabledSection', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(DisabledSection, {
      propsData: {
        disabled: false,
        ...props,
      },
      slots: {
        title: '<h2>Title</h2>',
        default: '<main>Content</main>',
      },
    });
  };

  const findOverlay = () => wrapper.findByTestId('disabled-section-overlay');
  const findAlert = () => wrapper.findComponent(GlAlert);

  it('renders the title slot', () => {
    createComponent();
    expect(wrapper.find('h2').text()).toBe('Title');
  });

  it('renders the default slot', () => {
    createComponent();
    expect(wrapper.find('main').text()).toBe('Content');
  });

  it('does not render the alert when not disabled', () => {
    createComponent({ disabled: false, error: 'error' });
    expect(findAlert().exists()).toBe(false);
  });

  it('renders the alert when disabled and has error', () => {
    const error = 'error message';
    createComponent({ disabled: true, error });
    const alert = findAlert();
    expect(alert.exists()).toBe(true);
    expect(alert.props()).toMatchObject({
      title: 'Invalid syntax',
      variant: 'warning',
      dismissible: false,
    });
    expect(alert.text()).toBe(error);
  });

  it('renders the overlay when disabled', () => {
    createComponent({ disabled: true });
    expect(findOverlay().exists()).toBe(true);
  });

  it('does not render the overlay when not disabled', () => {
    createComponent({ disabled: false });
    expect(findOverlay().exists()).toBe(false);
  });
});
