import MockAdapter from 'axios-mock-adapter';
import { GlModal, GlSearchBoxByType } from '@gitlab/ui';
import { stubComponent, RENDER_ALL_SLOTS_TEMPLATE } from 'helpers/stub_component';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import waitForPromises from 'helpers/wait_for_promises';
import axios from '~/lib/utils/axios_utils';
import { HTTP_STATUS_OK } from '~/lib/utils/http_status';
import FeatureLibraryModal from '~/super_sidebar/components/feature_library/feature_library_modal.vue';
import { EVENT_SEARCH_WITH_GEMINI_IN_FEATURE_LIBRARY_MODAL } from '~/super_sidebar/tracking_constants';

jest.mock('~/lib/utils/path_helpers/feature_library', () => ({
  onboardingFeatureLibrarySearchPath: () => '/-/onboarding/feature_library/search',
  onboardingFeatureLibraryAiSearchPath: () => '/-/onboarding/feature_library/ai_search',
}));

const SEARCH_URL = '/-/onboarding/feature_library/search';
const AI_SEARCH_URL = '/-/onboarding/feature_library/ai_search';

// The search_with_gemini_in_feature_library_modal event is EE-only (tiers:
// premium, ultimate), so its definition lives in ee/config/events/.
// FeatureLibraryModal behavior is covered in the CE spec:
// spec/frontend/super_sidebar/components/feature_library/feature_library_modal_spec.js
describe('FeatureLibraryModal (EE)', () => {
  let wrapper;
  let mockAxios;

  const defaultSections = [
    {
      id: 'code_menu',
      title: 'Code',
      items: [
        {
          id: 'repository',
          title: 'Repository',
          description: 'Browse and manage your code',
          library_icon: 'code',
        },
      ],
    },
  ];

  beforeEach(() => {
    mockAxios = new MockAdapter(axios);
  });

  afterEach(() => {
    mockAxios.restore();
  });

  const createWrapper = ({
    aiSearchAvailable = true,
    resourceId = 1,
    panelType = 'project',
  } = {}) => {
    wrapper = shallowMountExtended(FeatureLibraryModal, {
      propsData: { sections: defaultSections },
      provide: { panelType, aiSearchAvailable, resourceId },
      stubs: { GlModal: stubComponent(GlModal, { template: RENDER_ALL_SLOTS_TEMPLATE }) },
    });
  };

  const findSearch = () => wrapper.findComponent(GlSearchBoxByType);
  const findGeminiButton = () => wrapper.findComponentByTestId('search-with-gemini-button');

  const emitSearch = async (query) => {
    await findSearch().vm.$emit('input', query);
  };

  describe('Gemini tracking', () => {
    const { bindInternalEventDocument } = useMockInternalEventsTracking();
    const CATEGORY = undefined;

    beforeEach(() => {
      mockAxios.onGet(SEARCH_URL).reply(HTTP_STATUS_OK, { ids: [] });
      mockAxios.onGet(AI_SEARCH_URL).reply(HTTP_STATUS_OK, { ids: [], ai_search_available: true });
      createWrapper();
    });

    it('tracks the Gemini search event when the button is clicked', async () => {
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
      await emitSearch('re');
      await waitForPromises();
      await findGeminiButton().vm.$emit('click');

      expect(trackEventSpy).toHaveBeenCalledWith(
        EVENT_SEARCH_WITH_GEMINI_IN_FEATURE_LIBRARY_MODAL,
        {},
        CATEGORY,
      );
    });
  });
});
