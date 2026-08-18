import { GlDisclosureDropdown } from '@gitlab/ui';
import { nextTick } from 'vue';
import { shallowMountExtended, mountExtended } from 'helpers/vue_test_utils_helper';
import { visitUrl } from '~/lib/utils/url_utility';
import DashboardsListItemActions from 'ee/vue_shared/components/dashboards_list/dashboards_list_item_actions.vue';
import DashboardDeleteModal from 'ee/vue_shared/components/dashboards_list/dashboard_delete_modal.vue';

jest.mock('~/lib/utils/url_utility', () => ({
  ...jest.requireActual('~/lib/utils/url_utility'),
  visitUrl: jest.fn(),
}));

describe('DashboardsListItemActions (EE)', () => {
  let wrapper;

  const defaultProps = {
    id: 'gid://gitlab/Analytics::CustomDashboard/1',
    system: false,
    dashboardUrl: '/dashboards/my-dashboard',
    actionLabel: 'Actions',
  };

  const createWrapper = (props = {}, mountFn = shallowMountExtended) => {
    wrapper = mountFn(DashboardsListItemActions, {
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  const findDropdown = () => wrapper.findComponent(GlDisclosureDropdown);
  const findEditAction = () => wrapper.findComponentByTestId('dashboard-edit-action');
  const findShareAction = () => wrapper.findByText('Share');
  const findCopyAction = () => wrapper.findByText('Make a copy');
  const findDeleteAction = () => wrapper.findComponentByTestId('dashboard-delete-action');
  const findDeleteModal = () => wrapper.findComponent(DashboardDeleteModal);

  describe('rendering', () => {
    beforeEach(() => {
      createWrapper({}, mountExtended);
    });

    it('renders the actions dropdown', () => {
      expect(findDropdown().exists()).toBe(true);
    });

    it('renders the dropdown with correct props', () => {
      expect(findDropdown().props()).toMatchObject({
        icon: 'ellipsis_v',
        category: 'tertiary',
        textSrOnly: true,
        noCaret: true,
      });
    });

    it('renders all action items for custom dashboards', () => {
      expect(findEditAction().exists()).toBe(true);
      expect(findCopyAction().exists()).toBe(true);
      expect(findShareAction().exists()).toBe(true);
      expect(findDeleteAction().exists()).toBe(true);
    });

    it('renders delete action with danger variant', () => {
      expect(findDeleteAction().props('variant')).toBe('danger');
    });
  });

  describe('for system dashboards', () => {
    beforeEach(() => {
      createWrapper({ system: true }, mountExtended);
    });

    it('does not render edit action', () => {
      expect(findEditAction().exists()).toBe(false);
    });

    it('does not render delete action', () => {
      expect(findDeleteAction().exists()).toBe(false);
    });

    it('renders copy action', () => {
      expect(findCopyAction().exists()).toBe(true);
    });

    it('renders share action', () => {
      expect(findShareAction().exists()).toBe(true);
    });
  });

  describe('edit action', () => {
    beforeEach(() => {
      createWrapper({}, mountExtended);
    });

    it('redirects to the dashboard edit URL when clicked', () => {
      findEditAction().vm.$emit('action');
      expect(visitUrl).toHaveBeenCalledWith('/dashboards/my-dashboard/edit');
    });
  });

  describe('delete action', () => {
    beforeEach(() => {
      createWrapper({}, mountExtended);
    });

    it('shows the delete modal when clicked', async () => {
      const showSpy = jest.spyOn(findDeleteModal().vm, 'show');
      findDeleteAction().vm.$emit('action');
      await nextTick();
      expect(showSpy).toHaveBeenCalled();
    });

    it('passes correct dashboard ID to the modal', () => {
      expect(findDeleteModal().props('dashboardId')).toBe(defaultProps.id);
    });

    it('hides the modal when delete is successful', async () => {
      const hideSpy = jest.spyOn(findDeleteModal().vm, 'hide');
      findDeleteModal().vm.$emit('delete');
      await nextTick();
      expect(hideSpy).toHaveBeenCalled();
    });
  });

  describe('tooltip', () => {
    beforeEach(() => {
      createWrapper({ actionLabel: 'More options' });
    });

    it('renders with correct tooltip title', () => {
      expect(findDropdown().attributes('title')).toBe('More options');
    });
  });
});
