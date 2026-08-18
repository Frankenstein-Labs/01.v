import { GlDisclosureDropdown, GlDisclosureDropdownItem } from '@gitlab/ui';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ActionsCell from 'ee/security_configuration/components/scan_profiles/actions_cell.vue';

describe('ActionsCell', () => {
  let wrapper;

  const itemWithStatus = (rawStatus, buildId = 'gid://gitlab/CommitStatus/123') => ({
    securityConfigurationPath: '/project/-/security/configuration',
    scanStatus: { rawStatus, buildId },
  });

  const createComponent = (props = {}, mountFn = shallowMountExtended) => {
    wrapper = mountFn(ActionsCell, {
      propsData: {
        item: itemWithStatus(undefined),
        hasProfile: false,
        ...props,
      },
    });
  };

  const findDropdown = () => wrapper.findComponent(GlDisclosureDropdown);
  const findDropdownItems = () => wrapper.findAllComponents(GlDisclosureDropdownItem);
  const findProfileActionItem = () => findDropdownItems().at(0);
  const findNavigationActionItem = () => findDropdownItems().at(1);
  const findTroubleshootItem = () => wrapper.findByTestId('troubleshoot-failure-item');

  it('renders a ⋮ dropdown', () => {
    createComponent();

    expect(findDropdown().exists()).toBe(true);
    expect(findDropdown().attributes('icon')).toBe('ellipsis_v');
  });

  describe('profile actions', () => {
    it('when no profile is applied, renders "Enable profile-based scanning" action that emits apply-profile', () => {
      createComponent({ hasProfile: false });

      expect(findProfileActionItem().props('item').text).toBe('Enable profile-based scanning');

      findProfileActionItem().props('item').action();

      expect(wrapper.emitted('apply-profile')).toStrictEqual([[]]);
    });

    it('when a profile is applied, renders "Disable profile-based scanning" action that emits disable-profile', () => {
      createComponent({ hasProfile: true });

      expect(findProfileActionItem().props('item').text).toBe('Disable profile-based scanning');

      findProfileActionItem().props('item').action();

      expect(wrapper.emitted('disable-profile')).toStrictEqual([[]]);
    });
  });

  describe('navigation actions', () => {
    it('renders "View project configuration" as a link to the project security configuration path', () => {
      createComponent();

      expect(findNavigationActionItem().props('item')).toMatchObject({
        text: 'View project configuration',
        href: '/project/-/security/configuration',
      });
    });
  });

  describe('troubleshoot failure action', () => {
    it.each(['active', 'stale', 'unconfigured', 'pending', undefined])(
      'does not render when item.scanStatus.rawStatus is %s',
      (rawStatus) => {
        createComponent({ item: itemWithStatus(rawStatus) }, mountExtended);
        expect(findTroubleshootItem().exists()).toBe(false);
      },
    );

    it.each(['failed', 'warning'])('renders when item.scanStatus.rawStatus is %s', (rawStatus) => {
      createComponent({ item: itemWithStatus(rawStatus) }, mountExtended);
      expect(findTroubleshootItem().exists()).toBe(true);
      expect(findTroubleshootItem().text()).toContain('Troubleshoot failure');
    });

    it('emits troubleshoot-failure when activated', () => {
      createComponent({ item: itemWithStatus('failed') }, mountExtended);
      findTroubleshootItem().findComponent(GlDisclosureDropdownItem).vm.$emit('action');
      expect(wrapper.emitted('troubleshoot-failure')).toStrictEqual([[]]);
    });

    it.each(['failed', 'warning'])(
      'does not render for %s status when buildId is missing (analyzer-only row)',
      (rawStatus) => {
        createComponent({ item: itemWithStatus(rawStatus, null) }, mountExtended);
        expect(findTroubleshootItem().exists()).toBe(false);
      },
    );
  });
});
