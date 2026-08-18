import { shallowMount } from '@vue/test-utils';
import { GlAlert } from '@gitlab/ui';
import TopLevelGroupLimitAlert from 'ee_component/groups/components/top_level_group_limit_alert.vue';
import { helpPagePath } from '~/helpers/help_page_helper';

describe('TopLevelGroupLimitAlert', () => {
  let wrapper;

  const findAlert = () => wrapper.findComponent(GlAlert);

  const createComponent = () => {
    wrapper = shallowMount(TopLevelGroupLimitAlert, {
      stubs: {
        GlAlert,
      },
    });
  };

  beforeEach(() => {
    createComponent();
  });

  describe('when the component is created', () => {
    it('renders the alert with correct primary button text', () => {
      expect(findAlert().props('primaryButtonText')).toBe('Learn more about free user limits');
    });

    it('renders the alert with link to help page', () => {
      expect(findAlert().props('primaryButtonLink')).toBe(
        helpPagePath('user/free_user_limit#top-level-group-limits'),
      );
    });

    it('renders the alert as a warning variant', () => {
      expect(findAlert().props('variant')).toBe('warning');
    });

    it('displays the full error message', () => {
      const alertText = wrapper.text();
      expect(alertText).toContain('You have reached the limit of three top-level groups');
      expect(alertText).toContain('To create another group');
      expect(alertText).toContain('upgrade to a paid tier');
    });
  });
});
