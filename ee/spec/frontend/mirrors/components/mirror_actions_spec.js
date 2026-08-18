import { mountExtended } from 'helpers/vue_test_utils_helper';
import MirrorActions from 'ee/mirrors/components/mirror_actions.vue';
import { createPullMirror, createMirror } from 'jest/mirrors/components/mock_data';

describe('EE MirrorActions', () => {
  let wrapper;

  const createComponent = (mirror) => {
    wrapper = mountExtended(MirrorActions, {
      propsData: { mirror },
    });
  };

  const findSyncButton = () => wrapper.findComponentByTestId('update-now-button');
  const findDeleteButton = () => wrapper.findByTestId('delete-mirror-button');
  const findDisableButton = () => wrapper.findByTestId('disable-mirror-button');
  const findEnableButton = () => wrapper.findByTestId('enable-mirror-button');

  describe('archived pull mirror', () => {
    it('shows disabled sync button with archived tooltip', () => {
      createComponent(createPullMirror({ archived: true }));

      const syncButton = findSyncButton();
      expect(syncButton.exists()).toBe(true);
      expect(syncButton.props('disabled')).toBe(true);
      expect(syncButton.attributes('aria-label')).toContain('archived');
    });

    it('shows enabled sync button for non-archived pull mirrors', () => {
      createComponent(createPullMirror({ archived: false }));

      const syncButton = findSyncButton();
      expect(syncButton.exists()).toBe(true);
      expect(syncButton.props('disabled')).toBe(false);
    });

    it('shows delete button for archived pull mirrors', () => {
      createComponent(createPullMirror({ archived: true }));

      expect(findDeleteButton().exists()).toBe(true);
    });

    it('does not show toggle buttons for pull mirrors', () => {
      createComponent(createPullMirror({ archived: true }));

      expect(findDisableButton().exists()).toBe(false);
      expect(findEnableButton().exists()).toBe(false);
    });
  });

  describe('push mirrors behave like CE', () => {
    it('shows sync button for enabled push mirrors', () => {
      createComponent(createMirror({ enabled: true }));

      expect(findSyncButton().exists()).toBe(true);
      expect(findSyncButton().props('disabled')).toBe(false);
    });

    it('shows toggle button for push mirrors', () => {
      createComponent(createMirror({ enabled: true }));

      expect(findDisableButton().exists()).toBe(true);
    });
  });
});
