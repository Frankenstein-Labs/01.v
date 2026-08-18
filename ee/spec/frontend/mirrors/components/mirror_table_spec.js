import { GlTable, GlAlert } from '@gitlab/ui';
import { nextTick } from 'vue';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import MirrorTable from 'ee/mirrors/components/mirror_table.vue';
import { syncPullMirror, deletePullMirror } from 'ee/api/pull_mirror_api';
import { deleteRemoteMirror, syncRemoteMirror, updateRemoteMirror } from '~/api/remote_mirrors_api';
import { PULL_MIRROR_DELETED_EVENT } from '~/mirrors/constants';
import { PROJECT_ID, createMirror, createPullMirror } from 'jest/mirrors/components/mock_data';

jest.mock('ee/api/pull_mirror_api');
jest.mock('~/api/remote_mirrors_api');

describe('EE MirrorTable', () => {
  let wrapper;

  const createComponent = ({
    mirrors = [
      createMirror({ id: 1 }),
      createMirror({ id: 2, url: 'https://example.com/mirror2.git' }),
    ],
    pullMirror = null,
    settingsEnabled = true,
    repositoryMirrorsAvailable = false,
  } = {}) => {
    wrapper = mountExtended(MirrorTable, {
      propsData: {
        initialMirrors: mirrors,
        initialPullMirror: pullMirror,
      },
      provide: {
        projectId: PROJECT_ID,
        settingsEnabled,
        repositoryMirrorsAvailable,
      },
    });
  };

  const findTable = () => wrapper.findComponent(GlTable);
  const findAlert = () => wrapper.findComponent(GlAlert);
  const findEmptyState = () => wrapper.findByTestId('mirror-table-empty-state');
  const findSyncButtons = () => wrapper.findAllComponentsByTestId('update-now-button');
  const findDeleteButtons = () => wrapper.findAllByTestId('delete-mirror-button');
  const findDisableButtons = () => wrapper.findAllByTestId('disable-mirror-button');
  const findEnableButtons = () => wrapper.findAllByTestId('enable-mirror-button');
  const findTableRows = () => findTable().findAll('tbody tr');

  describe('pull mirror rendering', () => {
    it('renders pull mirror row when initialPullMirror is provided', () => {
      createComponent({ pullMirror: createPullMirror() });

      expect(findTableRows()).toHaveLength(3);
    });

    it('shows table when only pull mirror exists', () => {
      createComponent({ mirrors: [], pullMirror: createPullMirror() });

      expect(findEmptyState().exists()).toBe(false);
      expect(findTable().exists()).toBe(true);
      expect(findTableRows()).toHaveLength(1);
    });

    it('does not render pull mirror when initialPullMirror is null', () => {
      createComponent({ pullMirror: null });

      expect(findTableRows()).toHaveLength(2);
    });

    it('renders "Pull" direction for pull mirrors', () => {
      createComponent({ mirrors: [], pullMirror: createPullMirror() });

      expect(wrapper.text()).toContain('Pull');
    });

    it('does not show toggle buttons for pull mirrors', () => {
      createComponent({ mirrors: [], pullMirror: createPullMirror() });

      expect(findDisableButtons()).toHaveLength(0);
      expect(findEnableButtons()).toHaveLength(0);
    });

    it('shows sync and delete buttons for pull mirrors', () => {
      createComponent({ mirrors: [], pullMirror: createPullMirror() });

      expect(findSyncButtons()).toHaveLength(1);
      expect(findDeleteButtons()).toHaveLength(1);
    });
  });

  describe('handlePullSync', () => {
    it('sets pull mirror updateStatus to started and calls API', async () => {
      syncPullMirror.mockResolvedValue();
      createComponent({ mirrors: [], pullMirror: createPullMirror() });

      findSyncButtons().at(0).trigger('click');
      await nextTick();

      expect(syncPullMirror).toHaveBeenCalledWith(PROJECT_ID);
      expect(findSyncButtons().at(0).props('disabled')).toBe(true);
    });

    it('reverts updateStatus and shows alert on failure', async () => {
      syncPullMirror.mockRejectedValue(new Error('fail'));
      createComponent({ mirrors: [], pullMirror: createPullMirror() });

      findSyncButtons().at(0).trigger('click');
      await waitForPromises();

      expect(findAlert().text()).toBe('Failed to sync mirror.');
      expect(findSyncButtons().at(0).props('disabled')).toBe(false);
    });
  });

  describe('handlePullDelete', () => {
    it('removes pull mirror and dispatches pull-mirror-deleted event on success', async () => {
      deletePullMirror.mockResolvedValue();
      const eventHandler = jest.fn();
      document.addEventListener(PULL_MIRROR_DELETED_EVENT, eventHandler);

      createComponent({ pullMirror: createPullMirror() });
      expect(findTableRows()).toHaveLength(3);

      findDeleteButtons().at(0).trigger('click');
      await waitForPromises();

      expect(deletePullMirror).toHaveBeenCalledWith(PROJECT_ID);
      expect(findTableRows()).toHaveLength(2);
      expect(eventHandler).toHaveBeenCalled();

      document.removeEventListener(PULL_MIRROR_DELETED_EVENT, eventHandler);
    });

    it('shows alert on failure', async () => {
      deletePullMirror.mockRejectedValue(new Error('fail'));
      createComponent({ mirrors: [], pullMirror: createPullMirror() });

      findDeleteButtons().at(0).trigger('click');
      await waitForPromises();

      expect(findAlert().text()).toBe('Failed to remove mirror.');
      expect(findTableRows()).toHaveLength(1);
    });
  });

  describe('CE functionality still works in EE component', () => {
    it('handles push mirror sync via inherited methods', async () => {
      syncRemoteMirror.mockResolvedValue();
      createComponent({ mirrors: [createMirror({ id: 1 })], pullMirror: createPullMirror() });

      findSyncButtons().at(1).trigger('click');
      await nextTick();

      expect(syncRemoteMirror).toHaveBeenCalledWith(PROJECT_ID, 1);
    });

    it('handles push mirror delete via inherited methods', async () => {
      deleteRemoteMirror.mockResolvedValue();
      createComponent({ mirrors: [createMirror({ id: 1 })], pullMirror: createPullMirror() });

      findDeleteButtons().at(1).trigger('click');
      await waitForPromises();

      expect(deleteRemoteMirror).toHaveBeenCalledWith(PROJECT_ID, 1);
      expect(findTableRows()).toHaveLength(1);
    });

    it('handles push mirror toggle via inherited methods', async () => {
      updateRemoteMirror.mockResolvedValue();
      createComponent({ mirrors: [createMirror({ id: 1 })], pullMirror: createPullMirror() });

      findDisableButtons().at(0).trigger('click');
      await nextTick();

      expect(updateRemoteMirror).toHaveBeenCalledWith(PROJECT_ID, 1, { enabled: false });
    });
  });
});
