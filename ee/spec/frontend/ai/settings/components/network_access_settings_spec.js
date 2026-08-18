import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import NetworkAccessSettings from 'ee/ai/settings/components/network_access_settings.vue';
import DomainListCard from 'ee/ai/settings/components/domain_list_card.vue';

describe('NetworkAccessSettings', () => {
  let wrapper;

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMountExtended(NetworkAccessSettings, {
      propsData: { ...props },
    });
  };

  const findAllowlistCard = () => wrapper.findComponentByTestId('allowlist-card');
  const findDenylistCard = () => wrapper.findComponentByTestId('denylist-card');
  const findDomainListCards = () => wrapper.findAllComponents(DomainListCard);

  beforeEach(() => {
    createComponent();
  });

  describe('section headings', () => {
    it('renders "Network access" heading', () => {
      expect(wrapper.text()).toContain('Network access');
    });

    it('renders "Allowed domains" subheading', () => {
      expect(wrapper.text()).toContain('Allowed domains');
    });

    it('renders "Blocked domains" subheading', () => {
      expect(wrapper.text()).toContain('Blocked domains');
    });

    it('renders denylist description text', () => {
      expect(wrapper.text()).toContain(
        'Domains in the denylist are always blocked, even if they appear in the allowlist.',
      );
    });

    it('renders h3 heading with gl-heading-4 class', () => {
      const heading = wrapper.find('h3');
      expect(heading.exists()).toBe(true);
      expect(heading.classes()).toContain('gl-heading-4');
    });

    it('renders h4 subheadings with gl-heading-5 class', () => {
      const subheadings = wrapper.findAll('h4');
      expect(subheadings).toHaveLength(2);
      expect(subheadings.at(0).classes()).toContain('gl-heading-5');
      expect(subheadings.at(1).classes()).toContain('gl-heading-5');
    });
  });

  describe('DomainListCard instances', () => {
    it('renders two DomainListCard components', () => {
      expect(findDomainListCards()).toHaveLength(2);
    });

    it('passes domainType="ALLOWED" to the allowlist card', () => {
      expect(findAllowlistCard().props('domainType')).toBe('ALLOWED');
    });

    it('passes domainType="DENIED" to the denylist card', () => {
      expect(findDenylistCard().props('domainType')).toBe('DENIED');
    });

    it('passes correct title to allowlist card', () => {
      expect(findAllowlistCard().props('title')).toBe('Allowlist');
    });

    it('passes correct title to denylist card', () => {
      expect(findDenylistCard().props('title')).toBe('Denylist');
    });

    it('passes correct emptyStateText to allowlist card', () => {
      expect(findAllowlistCard().props('emptyStateText')).toBe('No allowlist entries.');
    });

    it('passes correct emptyStateText to denylist card', () => {
      expect(findDenylistCard().props('emptyStateText')).toBe('No denylist entries.');
    });

    it('passes correct errorText to allowlist card', () => {
      expect(findAllowlistCard().props('errorText')).toBe('Failed to load allowlist domains.');
    });

    it('passes correct errorText to denylist card', () => {
      expect(findDenylistCard().props('errorText')).toBe('Failed to load denylist domains.');
    });
  });

  describe('groupFullPath prop', () => {
    it('does not pass groupFullPath by default', () => {
      expect(findAllowlistCard().props('groupFullPath')).toBeNull();
      expect(findDenylistCard().props('groupFullPath')).toBeNull();
    });

    it('passes groupFullPath to both cards when provided', () => {
      createComponent({ props: { groupFullPath: 'my-group' } });

      expect(findAllowlistCard().props('groupFullPath')).toBe('my-group');
      expect(findDenylistCard().props('groupFullPath')).toBe('my-group');
    });
  });
});
