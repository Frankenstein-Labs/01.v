import { nextTick } from 'vue';
import { GlDrawer } from '@gitlab/ui';
import { shallowMountExtended, mountExtended } from 'helpers/vue_test_utils_helper';
import { visitUrl } from '~/lib/utils/url_utility';
import DashboardSettingsDrawer from 'ee/explore/analytics_dashboards/components/dashboard_settings_drawer.vue';
import DashboardSettingsForm from 'ee/explore/analytics_dashboards/components/dashboard_settings_form.vue';
import DashboardDeleteModal from 'ee/vue_shared/components/dashboards_list/dashboard_delete_modal.vue';

jest.mock('~/lib/utils/dom_utils', () => ({
  getContentWrapperHeight: () => '123',
}));

jest.mock('~/lib/utils/url_utility', () => ({
  ...jest.requireActual('~/lib/utils/url_utility'),
  visitUrl: jest.fn(),
}));

describe('DashboardSettingsDrawer', () => {
  let wrapper;

  const defaultPropsData = {
    open: false,
    dashboardConfig: {
      title: 'Test Dashboard',
      description: 'Test Description',
      panels: [],
    },
    dashboardId: 'gid://gitlab/Analytics::CustomDashboard/1',
  };

  const createComponent = (props = {}, mountFn = shallowMountExtended) => {
    wrapper = mountFn(DashboardSettingsDrawer, {
      propsData: {
        ...defaultPropsData,
        ...props,
      },
      provide: {
        exploreAnalyticsDashboardsPath: '/dashboards/',
      },
    });
  };

  const findDrawer = () => wrapper.findComponent(GlDrawer);
  const findFormSettings = () => wrapper.findComponent(DashboardSettingsForm);
  const findDeleteModal = () => wrapper.findComponent(DashboardDeleteModal);
  const findSaveButton = () => wrapper.findComponentByTestId('settings-save-button');
  const findCancelButton = () => wrapper.findComponentByTestId('settings-cancel-button');
  const findDeleteButton = () => wrapper.findComponentByTestId('settings-delete-button');

  it('emits close when GlDrawer emits close', async () => {
    createComponent();

    findDrawer().vm.$emit('close');
    await nextTick();

    expect(wrapper.emitted('close')).toHaveLength(1);
  });

  describe('form', () => {
    beforeEach(() => {
      createComponent({ open: true });
    });

    it('renders the DashboardSettingsForm component', () => {
      expect(findFormSettings().exists()).toBe(true);
    });

    it('passes the config title and description to the form', () => {
      expect(findFormSettings().props('value')).toEqual({
        title: 'Test Dashboard',
        description: 'Test Description',
      });
    });

    it('emits update when the form changes', () => {
      findFormSettings().vm.$emit('input', {
        title: 'Updated Title',
        description: 'Updated Description',
      });

      expect(wrapper.emitted('update')).toEqual([
        [
          {
            ...defaultPropsData.dashboardConfig,
            title: 'Updated Title',
            description: 'Updated Description',
          },
        ],
      ]);
    });

    it('passes isLoading as false to the form by default', () => {
      expect(findFormSettings().props('isLoading')).toBe(false);
    });

    it('passes isSaving to the form as isLoading', () => {
      createComponent({ open: true, isSaving: true });

      expect(findFormSettings().props('isLoading')).toBe(true);
    });
  });

  describe('form actions', () => {
    beforeEach(() => {
      createComponent({ open: true });
    });

    it('renders the save button', () => {
      expect(findSaveButton().exists()).toBe(true);
      expect(findSaveButton().text()).toBe('Save');
    });

    it('emits save when the save button is pressed', async () => {
      findSaveButton().vm.$emit('click');
      await nextTick();

      expect(wrapper.emitted('save')).toHaveLength(1);
    });

    it('emits close when the cancel button is pressed', async () => {
      findCancelButton().vm.$emit('click');
      await nextTick();

      expect(wrapper.emitted('close')).toHaveLength(1);
    });
  });

  describe('saving state', () => {
    beforeEach(() => {
      createComponent({ open: true, isSaving: true });
    });

    it('shows the save button as loading', () => {
      expect(findSaveButton().props('loading')).toBe(true);
    });

    it('disables the cancel button', () => {
      expect(findCancelButton().props('disabled')).toBe(true);
    });

    it('disables the delete button', () => {
      expect(findDeleteButton().props('disabled')).toBe(true);
    });
  });

  describe('delete functionality', () => {
    beforeEach(() => {
      createComponent({ open: true }, mountExtended);
    });

    it('shows the delete modal when Delete dashboard is pressed', async () => {
      const showSpy = jest.spyOn(findDeleteModal().vm, 'show');
      findDeleteButton().vm.$emit('click');
      await nextTick();

      expect(showSpy).toHaveBeenCalled();
    });

    it('redirects back to the list view when delete is successful', async () => {
      findDeleteModal().vm.$emit('delete');
      await nextTick();

      expect(visitUrl).toHaveBeenCalledWith('/dashboards/');
    });
  });
});
