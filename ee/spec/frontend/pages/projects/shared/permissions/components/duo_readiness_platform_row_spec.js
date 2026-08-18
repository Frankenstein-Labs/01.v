import { mountExtended } from 'helpers/vue_test_utils_helper';
import DuoReadinessPlatformRow from 'ee/pages/projects/shared/permissions/components/duo_readiness_platform_row.vue';
import DuoReadinessRow from '~/pages/projects/shared/permissions/components/duo_readiness_row.vue';

const defaultReadiness = {
  platformEnabled: true,
  isSaas: false,
  groupSettingsPath: '/groups/g/-/edit',
  adminSettingsPath: '/admin/gitlab_duo',
};

describe('DuoReadinessPlatformRow', () => {
  let wrapper;

  const createComponent = (readiness = {}) => {
    wrapper = mountExtended(DuoReadinessPlatformRow, {
      propsData: { readiness: { ...defaultReadiness, ...readiness } },
    });
  };

  const findRow = () => wrapper.findComponent(DuoReadinessRow);
  const findAction = () => wrapper.findByTestId('platform-row-action');

  it('is done and points at instance settings on self-managed', () => {
    createComponent();

    expect(findRow().props('status')).toBe('done');
    expect(findRow().props('description')).toBe('On for this instance. Administrators control it.');
    expect(findAction().attributes('href')).toBe('/admin/gitlab_duo');
    expect(findAction().text()).toBe('View');
  });

  // The row sits inside the unsaved settings form, so leaving in the same tab would discard
  // whatever the user had toggled.
  it('opens the settings it links to in a new tab', () => {
    createComponent();

    expect(findAction().attributes('target')).toBe('_blank');
  });

  it('points at group settings on SaaS, where the switch actually lives', () => {
    createComponent({ isSaas: true });

    expect(findRow().props('description')).toBe('On for this group. Group Owners control it.');
    expect(findAction().attributes('href')).toBe('/groups/g/-/edit');
  });

  it('is an error naming who can turn it on when off', () => {
    createComponent({ platformEnabled: false });

    expect(findRow().props('status')).toBe('error');
    expect(findRow().props('description')).toBe(
      'Off for this instance. Only an administrator can turn it on.',
    );
    expect(findAction().text()).toBe('Admin settings');
  });

  it('offers no action when the viewer cannot reach those settings', () => {
    createComponent({ platformEnabled: false, adminSettingsPath: null });

    expect(findAction().exists()).toBe(false);
  });
});
