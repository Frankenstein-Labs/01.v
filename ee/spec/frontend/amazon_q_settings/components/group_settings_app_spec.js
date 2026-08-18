import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { updateGroupSettings } from 'ee/api/groups_api';
import showToast from '~/vue_shared/plugins/global_toast';
import { createAlert } from '~/alert';
import { AVAILABILITY_OPTIONS } from 'ee/ai/settings/constants';
import GroupSettingsApp from 'ee/amazon_q_settings/components/group_settings_app.vue';
import AmazonQSettingsBlock from 'ee/amazon_q_settings/components/amazon_q_settings_block.vue';

jest.mock('ee/api/groups_api');
jest.mock('~/vue_shared/plugins/global_toast');
jest.mock('~/alert');

const TEST_GROUP_ID = '7';
const TEST_INIT_AVAILABILITY = AVAILABILITY_OPTIONS.DEFAULT_OFF;
const TEST_NEW_AVAILABILITY = AVAILABILITY_OPTIONS.DEFAULT_ON;

describe('ee/amazon_q_settings/components/group_settings_app.vue', () => {
  let wrapper;
  let resolveUpdateGroupSettings;
  let rejectUpdateGroupSettings;

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(GroupSettingsApp, {
      propsData: {
        groupId: TEST_GROUP_ID,
        initAvailability: TEST_INIT_AVAILABILITY,
        initAutoReviewEnabled: false,
        ...props,
      },
    });
  };

  const findSettingsBlock = () => wrapper.findComponent(AmazonQSettingsBlock);

  beforeEach(() => {
    updateGroupSettings.mockImplementation(() => {
      return new Promise((resolve, reject) => {
        resolveUpdateGroupSettings = resolve;
        rejectUpdateGroupSettings = reject;
      });
    });
  });

  describe('default', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders settings block', () => {
      expect(findSettingsBlock().props()).toEqual({
        initAvailability: TEST_INIT_AVAILABILITY,
        initAutoReviewEnabled: false,
        isLoading: false,
      });
    });
  });

  describe('when settings block submits', () => {
    beforeEach(async () => {
      createComponent();

      await findSettingsBlock().vm.$emit('submit', {
        availability: TEST_NEW_AVAILABILITY,
      });
    });

    it('renders settings block with loading', () => {
      expect(findSettingsBlock().props('isLoading')).toBe(true);
    });

    it('calls updateGroupSettings', () => {
      expect(updateGroupSettings).toHaveBeenCalledTimes(1);
      expect(updateGroupSettings).toHaveBeenCalledWith(TEST_GROUP_ID, {
        duo_availability: TEST_NEW_AVAILABILITY,
      });
    });

    it('after resolves, shows toast and updates availability', async () => {
      expect(findSettingsBlock().props('initAvailability')).toEqual(TEST_INIT_AVAILABILITY);
      expect(showToast).not.toHaveBeenCalled();

      resolveUpdateGroupSettings();
      await waitForPromises();

      expect(showToast).toHaveBeenCalledTimes(1);
      expect(showToast).toHaveBeenCalledWith('Group was successfully updated.', {
        variant: 'success',
      });
      expect(findSettingsBlock().props()).toEqual({
        initAvailability: TEST_NEW_AVAILABILITY,
        initAutoReviewEnabled: false,
        isLoading: false,
      });
    });

    it('after rejects, shows alert', async () => {
      const error = new Error('BOOM!');
      expect(createAlert).not.toHaveBeenCalled();

      rejectUpdateGroupSettings(error);
      await waitForPromises();

      expect(createAlert).toHaveBeenCalledTimes(1);
      expect(createAlert).toHaveBeenCalledWith({
        error,
        captureError: true,
        message: 'An error occurred while updating your settings.',
      });
    });
  });
});
