import { nextTick } from 'vue';
import SeedExternalAgents from 'ee/ai/settings/components/seed_external_agents.vue';
import axios from '~/lib/utils/axios_utils';
import { HTTP_STATUS_CREATED } from '~/lib/utils/http_status';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import {
  AI_CATALOG_SEED_EXTERNAL_AGENTS_PATH,
  AI_CATALOG_ALREADY_SEEDED_ERROR,
} from 'ee/ai/settings/constants';

jest.mock('~/lib/utils/axios_utils');

describe('SeedExternalAgents', () => {
  let wrapper;

  const mockToast = {
    show: jest.fn(),
  };

  const findSeedExternalAgentsButton = () =>
    wrapper.findComponentByTestId('seed-external-agents-button');

  const createWrapper = (provide = {}) => {
    const defaultMountOptions = {
      provide: {
        isSaaS: false,
        ...provide,
      },
      mocks: {
        $toast: mockToast,
      },
    };

    wrapper = shallowMountExtended(SeedExternalAgents, defaultMountOptions);
  };

  beforeEach(() => {
    jest.clearAllMocks();

    axios.post = jest.fn().mockResolvedValue({ status: 200 });
  });

  describe('seedExternalAgents', () => {
    const clickSeedButton = () => findSeedExternalAgentsButton().vm.$emit('click');

    it('renders seed external agents section', () => {
      createWrapper({});

      expect(findSeedExternalAgentsButton().exists()).toBe(true);
    });

    describe('when user clicks seed button', () => {
      beforeEach(() => {
        createWrapper();
      });

      it('sets loading state and calls the correct API endpoint', async () => {
        clickSeedButton();
        await nextTick();
        expect(findSeedExternalAgentsButton().props('loading')).toBe(true);
        await waitForPromises();

        expect(axios.post).toHaveBeenCalledWith(AI_CATALOG_SEED_EXTERNAL_AGENTS_PATH);
        expect(findSeedExternalAgentsButton().props('loading')).toBe(false);
      });
    });

    describe('when request succeeds', () => {
      beforeEach(() => {
        createWrapper();
        axios.post.mockResolvedValueOnce({ status: HTTP_STATUS_CREATED });
      });

      it('shows success toast and disables the button', async () => {
        clickSeedButton();
        await waitForPromises();

        expect(mockToast.show).toHaveBeenCalledWith('Agents successfully added to AI Catalog.');
        expect(findSeedExternalAgentsButton().props('disabled')).toBe(true);
      });
    });

    describe('when request fails with "already in catalog" error', () => {
      beforeEach(() => {
        createWrapper();
        axios.post.mockRejectedValueOnce({
          response: {
            data: {
              message: AI_CATALOG_ALREADY_SEEDED_ERROR,
            },
          },
        });
      });

      it('shows already seeded toast and disables the button', async () => {
        clickSeedButton();
        await waitForPromises();

        expect(mockToast.show).toHaveBeenCalledWith('Agents already in AI Catalog.');
        expect(findSeedExternalAgentsButton().props('disabled')).toBe(true);
      });
    });

    describe('when request fails', () => {
      beforeEach(() => {
        createWrapper();
        axios.post.mockRejectedValueOnce({
          response: {
            data: {
              message: 'Some other error',
            },
          },
        });
      });

      it('shows error toast but does not disable the button', async () => {
        clickSeedButton();
        await waitForPromises();

        expect(mockToast.show).toHaveBeenCalledWith('Failed to add agents to AI Catalog.');
        expect(findSeedExternalAgentsButton().props('disabled')).toBe(false);
      });
    });
  });
});
