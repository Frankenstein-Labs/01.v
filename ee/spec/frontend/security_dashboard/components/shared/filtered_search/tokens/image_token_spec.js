import { GlFilteredSearchToken, GlLoadingIcon } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { createAlert } from '~/alert';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import agentImagesQuery from 'ee/security_dashboard/graphql/queries/agent_images.query.graphql';
import projectImagesQuery from 'ee/security_dashboard/graphql/queries/project_images.query.graphql';
import ImageToken from 'ee/security_dashboard/components/shared/filtered_search/tokens/image_token.vue';
import SearchSuggestion from 'ee/security_dashboard/components/shared/filtered_search/components/search_suggestion.vue';
import { OPERATORS_OR } from '~/vue_shared/components/filtered_search_bar/constants';
import { stubComponent } from 'helpers/stub_component';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';
import {
  agentVulnerabilityImages,
  projectVulnerabilityImages,
} from 'ee_jest/security_dashboard/components/mock_data';

Vue.use(VueApollo);
jest.mock('~/alert');

describe('Image Token component', () => {
  let wrapper;
  const projectFullPath = 'test/path';
  const agentProvide = {
    agentName: 'agent-1',
    fullPath: 'agent/path',
  };
  const defaultAgentQueryResolver = jest.fn().mockResolvedValue(agentVulnerabilityImages);
  const defaultProjectQueryResolver = jest.fn().mockResolvedValue(projectVulnerabilityImages);

  const mockConfig = {
    multiSelect: true,
    unique: true,
    operators: OPERATORS_OR,
  };

  const createWrapper = ({
    value = {},
    active = false,
    stubs,
    provide = {},
    agentQueryResolver = defaultAgentQueryResolver,
    projectQueryResolver = defaultProjectQueryResolver,
    mountFn = shallowMountExtended,
  } = {}) => {
    wrapper = mountFn(ImageToken, {
      apolloProvider: createMockApollo([
        [agentImagesQuery, agentQueryResolver],
        [projectImagesQuery, projectQueryResolver],
      ]),
      propsData: {
        config: mockConfig,
        value,
        active,
      },
      provide: {
        portalName: 'fake target',
        alignSuggestions: jest.fn(),
        termsAsTokens: () => false,
        projectFullPath,
        ...provide,
      },
      stubs: {
        SearchSuggestion,
        ...stubs,
      },
    });
  };

  const findFilteredSearchToken = () => wrapper.findComponent(GlFilteredSearchToken);
  const isOptionChecked = (v) =>
    wrapper.findComponentByTestId(`suggestion-${v}`).props('selected') === true;

  const clickDropdownItem = async (...ids) => {
    await Promise.all(
      ids.map((id) => {
        findFilteredSearchToken().vm.$emit('select', id);
        return nextTick();
      }),
    );

    findFilteredSearchToken().vm.$emit('complete');
    await nextTick();
  };

  describe('default view', () => {
    const findViewSlot = () => wrapper.findByTestId('slot-view');
    const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
    const findTruncateTexts = () =>
      wrapper
        .findAllComponents(SearchSuggestion)
        .wrappers.filter((component) => component.props('truncate'))
        .map((component) => component.props('text'));

    const stubs = {
      GlFilteredSearchToken: stubComponent(GlFilteredSearchToken, {
        template: `
				<div>
						<div data-testid="slot-view">
								<slot name="view"></slot>
						</div>
						<div>
								<slot name="suggestions"></slot>
						</div>
				</div>`,
      }),
      GlLoadingIcon,
    };

    beforeEach(() => {
      createWrapper({
        stubs,
      });
    });

    it('shows the label', () => {
      expect(findViewSlot().text()).toBe('All images');
    });

    it('shows the dropdown with correct options', async () => {
      await waitForPromises();

      expect(findTruncateTexts()).toEqual([
        'All images',
        'long-image-name',
        'second-long-image-name',
        'third-image',
      ]);
    });

    it('shows the loading icon when images are not yet loaded', async () => {
      expect(findLoadingIcon().exists()).toBe(true);

      await waitForPromises();

      expect(findLoadingIcon().exists()).toBe(false);
    });

    describe('with agent dashboard', () => {
      beforeEach(() => {
        createWrapper({
          stubs,
          provide: agentProvide,
        });
      });

      it('shows the dropdown with correct options', async () => {
        await waitForPromises();

        expect(findTruncateTexts()).toEqual(['All images', 'long-image-name']);
      });
    });
  });

  it('shows an alert on a failed GraphQL request', async () => {
    createWrapper({ projectQueryResolver: jest.fn().mockRejectedValue() });
    await waitForPromises();

    expect(createAlert).toHaveBeenCalledWith({ message: 'Failed to load images.' });
  });

  describe('item selection', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('toggles the item selection when clicked on', async () => {
      await clickDropdownItem('long-image-name', 'second-long-image-name');

      expect(isOptionChecked('long-image-name')).toBe(true);
      expect(isOptionChecked('second-long-image-name')).toBe(true);
      expect(isOptionChecked('third-image')).toBe(false);
      expect(isOptionChecked('ALL')).toBe(false);
    });

    it('selects only "All images" when that item is selected', async () => {
      await clickDropdownItem('long-image-name', 'ALL');

      expect(isOptionChecked('long-image-name')).toBe(false);
      expect(isOptionChecked('second-long-image-name')).toBe(false);
      expect(isOptionChecked('third-image')).toBe(false);
      expect(isOptionChecked('ALL')).toBe(true);
    });

    it('selects "All images" when last selected item is deselected', async () => {
      // Select and deselect "long-image-name"
      await clickDropdownItem('long-image-name', 'long-image-name');

      expect(isOptionChecked('long-image-name')).toBe(false);
      expect(isOptionChecked('second-long-image-name')).toBe(false);
      expect(isOptionChecked('third-image')).toBe(false);
      expect(isOptionChecked('ALL')).toBe(true);
    });
  });

  describe('toggle text', () => {
    const findSlotView = () => wrapper.findAllByTestId('filtered-search-token-segment').at(2);

    beforeEach(() => {
      createWrapper({ mountFn: mountExtended });
    });

    it('shows "long-image-name, second-long-image-name" when long-image-name and second-long-image-name are selected', async () => {
      await clickDropdownItem('long-image-name', 'second-long-image-name');
      expect(findSlotView().text()).toBe('long-image-name, second-long-image-name');
    });

    it('shows "long-image-name, second-long-image-name +1 more" when long-image-name, second-long-image-name, and third-image are selected', async () => {
      await clickDropdownItem('long-image-name', 'second-long-image-name', 'third-image');
      expect(findSlotView().text()).toBe('long-image-name, second-long-image-name +1 more');
    });

    it('shows "long-image-name" when only long-image-name is selected', async () => {
      await clickDropdownItem('long-image-name');
      expect(findSlotView().text()).toBe('long-image-name');
    });
  });
});
